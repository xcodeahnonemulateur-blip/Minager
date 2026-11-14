import Foundation
import Combine
import Network

/// Experimental on-device Monero Stratum miner using RandomX LIGHT (256 MiB).
/// It never handles wallet private keys. Mining only while in foreground.
final class MoneroMineEngine: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var status = "En attente du QR code Monero"
    @Published private(set) var rate = 0.0
    @Published private(set) var hashes: UInt64 = 0
    @Published private(set) var accepted = 0
    @Published private(set) var rejected = 0

    private let lock = NSLock()
    private let networkQueue = DispatchQueue(label: "fr.minager.stratum")
    private let workerQueue = DispatchQueue(label: "fr.minager.randomx", qos: .utility)
    private var conn: NWConnection?
    private var started = false
    private var epoch: UInt64 = 0
    private var lineBuffer = Data()
    private var sessionId = ""
    private var activeJob: MiningJob?
    private var pendingIDs = Set<Int>()
    private var nextRequestID = 2
    // Epoch of the worker queued on the SERIAL worker queue.
    private var workerEpoch: UInt64?
    private let hostname = "pool.hashvault.pro"
    private let poolPort: UInt16 = 443

    struct MiningJob: Equatable {
        let id: String
        let seed: Data
        let blob: Data
        let target: UInt64
        let useV2: Bool
        let epoch: UInt64
    }

    func start(to publicAddress: String) {
        guard MoneroQRCode.address(from: publicAddress) != nil else {
            show("Adresse Monero incorrecte")
            return
        }
        lock.lock()
        guard !started else { lock.unlock(); return }
        started = true
        epoch += 1
        let myEpoch = epoch
        activeJob = nil
        pendingIDs = []
        // Do not overwrite workerEpoch: the old worker may be draining.
        sessionId = ""
        lock.unlock()
        DispatchQueue.main.async {
            self.running = true
            self.rate = 0
            self.hashes = 0
            self.accepted = 0
            self.rejected = 0
            self.status = "Connexion sécurisée au pool…"
        }
        networkQueue.async { [weak self] in
            self?.connect(address: publicAddress, epoch: myEpoch)
        }
    }

    func stop(reason: String = "Minage arrêté") {
        lock.lock()
        started = false
        epoch += 1
        activeJob = nil
        let previous = conn
        conn = nil
        lock.unlock()
        previous?.cancel()
        DispatchQueue.main.async {
            self.running = false
            self.rate = 0
            self.status = reason
        }
    }

    private func isRunning(_ token: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return started && epoch == token
    }

    private func show(_ text: String) {
        DispatchQueue.main.async { self.status = text }
    }

    private func connect(address: String, epoch token: UInt64) {
        guard isRunning(token), let port = NWEndpoint.Port(rawValue: poolPort) else { return }
        // TLS is mandatory; this is a public payout address and never a secret key.
        let connection = NWConnection(host: NWEndpoint.Host(hostname), port: port, using: .tls)
        lock.lock()
        conn = connection
        lock.unlock()
        lineBuffer.removeAll()
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self, self.isRunning(token) else { return }
            switch state {
            case .ready:
                self.show("Connexion TLS établie • authentification au pool")
                let request: [String: Any] = [
                    "id": 1, "jsonrpc": "2.0", "method": "login",
                    "params": ["login": address, "pass": "Minage-iPhone7", "agent": "Minager/0.3 iOS RandomX-light"]
                ]
                self.send(request, on: connection)
                self.receive(on: connection, epoch: token)
            case .failed(let error):
                self.stop(reason: "Pool injoignable : \(error.localizedDescription)")
            case .cancelled:
                break
            default: break
            }
        }
        connection.start(queue: networkQueue)
    }

    private func send(_ payload: [String: Any], on connection: NWConnection) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              var msg = String(data: data, encoding: .utf8) else { return }
        msg += "\n"
        connection.send(content: Data(msg.utf8), completion: .contentProcessed { [weak self] error in
            if let error = error { self?.show("Envoi pool : \(error.localizedDescription)") }
        })
    }

    private func receive(on connection: NWConnection, epoch token: UInt64) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, done, error in
            guard let self = self, self.isRunning(token) else { return }
            if let error = error {
                self.stop(reason: "Connexion interrompue : \(error.localizedDescription)")
                return
            }
            if let data = data, !data.isEmpty {
                self.lineBuffer.append(data)
                if self.lineBuffer.count > 64_000 {
                    self.stop(reason: "Réponse du pool trop longue")
                    return
                }
                while let index = self.lineBuffer.firstIndex(of: 10) {
                    let packet = Data(self.lineBuffer.prefix(upTo: index))
                    self.lineBuffer.removeSubrange(...index)
                    self.processLine(packet, epoch: token)
                }
            }
            if done { self.stop(reason: "Connexion au pool fermée") }
            else { self.receive(on: connection, epoch: token) }
        }
    }

    private func processLine(_ line: Data, epoch token: UInt64) {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { return }
        if let err = obj["error"] as? [String: Any],
           let message = err["message"] as? String {
            show("Pool : \(message)")
            if let id = obj["id"] as? Int, id > 1 {
                lock.lock()
                pendingIDs.remove(id)
                lock.unlock()
                DispatchQueue.main.async { self.rejected += 1 }
            }
            return
        }
        if let method = obj["method"] as? String, method == "job",
           let params = obj["params"] as? [String: Any] {
            loadJob(params, epoch: token)
            return
        }
        if let id = obj["id"] as? Int, id == 1,
           let result = obj["result"] as? [String: Any] {
            lock.lock()
            sessionId = result["id"] as? String ?? ""
            lock.unlock()
            if let job = result["job"] as? [String: Any] { loadJob(job, epoch: token) }
            return
        }
        if let id = obj["id"] as? Int, id > 1 {
            lock.lock()
            let found = pendingIDs.remove(id) != nil
            lock.unlock()
            if found {
                DispatchQueue.main.async {
                    self.accepted += 1
                    self.status = "Part acceptée par le pool ✓"
                }
            }
        }
    }

    private func loadJob(_ raw: [String: Any], epoch token: UInt64) {
        guard let id = raw["job_id"] as? String,
              let seedText = raw["seed_hash"] as? String,
              let blobText = raw["blob"] as? String,
              let targetText = raw["target"] as? String,
              let seed = Self.decodeHex(seedText), seed.count == 32,
              let blob = Self.decodeHex(blobText), blob.count >= 43,
              let difficulty = Self.poolTarget(targetText) else {
            show("Job du pool incompatible avec RandomX Monero")
            return
        }
        if let algo = raw["algo"] as? String,
           !["rx/0", "rx/2", "rx/v2"].contains(algo) {
            show("Algorithme pool non pris en charge : \(algo)")
            return
        }
        let v2 = ["rx/2", "rx/v2"].contains(raw["algo"] as? String ?? "rx/0")
        let job = MiningJob(id: id, seed: seed, blob: blob, target: difficulty, useV2: v2, epoch: token)
        lock.lock()
        activeJob = job
        let shouldLaunch = workerEpoch != token
        if shouldLaunch { workerEpoch = token }
        lock.unlock()
        show("Travail reçu • initialisation RandomX light…")
        if shouldLaunch {
            workerQueue.async { [weak self] in self?.mine(epoch: token) }
        }
    }

    private func mine(epoch token: UInt64) {
        defer {
            lock.lock()
            if workerEpoch == token { workerEpoch = nil }
            lock.unlock()
        }
        var activeSeed = Data()
        var activeV2 = false
        var native: OpaquePointer?
        defer { if let native = native { minager_rx_destroy(native) } }
        var attempts: UInt64 = 0
        var lastReported: UInt64 = 0
        var tick = Date()
        while isRunning(token) {
            if ProcessInfo.processInfo.thermalState == .serious ||
                ProcessInfo.processInfo.thermalState == .critical {
                stop(reason: "Sécurité : iPhone trop chaud")
                return
            }
            lock.lock()
            let job = activeJob
            let minerId = sessionId
            let currentConn = conn
            lock.unlock()
            guard let job = job, !minerId.isEmpty else {
                Thread.sleep(forTimeInterval: 0.15)
                continue
            }
            if activeSeed != job.seed || activeV2 != job.useV2 {
                if let native = native { minager_rx_destroy(native) }
                native = nil
                // Memory allocation & Argon2 cache initialization may be slow on A10.
                native = job.seed.withUnsafeBytes { key in
                    minager_rx_create(key.bindMemory(to: UInt8.self).baseAddress, job.seed.count, job.useV2 ? 1 : 0)
                }
                guard native != nil else {
                    stop(reason: "Mémoire insuffisante pour RandomX light (256 Mo)")
                    return
                }
                activeSeed = job.seed
                activeV2 = job.useV2
                show("Calcul RandomX light sur l'Apple A10…")
            }
            guard let native = native else { return }
            var message = [UInt8](job.blob)
            var nonce = UInt32.random(in: UInt32.min...UInt32.max)
            var localAttempts = 0
            // Re-read the job often so a new block is not mined with stale data.
            while isRunning(token) && localAttempts < 32 {
                lock.lock()
                let stillSameJob = activeJob == job
                lock.unlock()
                if !stillSameJob { break }
                message[39] = UInt8(truncatingIfNeeded: nonce)
                message[40] = UInt8(truncatingIfNeeded: nonce >> 8)
                message[41] = UInt8(truncatingIfNeeded: nonce >> 16)
                message[42] = UInt8(truncatingIfNeeded: nonce >> 24)
                var output = [UInt8](repeating: 0, count: 32)
                let messageCount = message.count
                message.withUnsafeBytes { input in
                    output.withUnsafeMutableBytes { digest in
                        minager_rx_hash(native, input.baseAddress, messageCount, digest.baseAddress)
                    }
                }
                localAttempts += 1
                attempts += 1
                if localAttempts % 4 == 0 && (ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical) {
                    stop(reason: "Sécurité : iPhone trop chaud")
                    return
                }
                if Self.isShare(hash: output, target: job.target) {
                    let hexNonce = Self.encodeHex(Array(message[39..<43]))
                    let digest = Self.encodeHex(output)
                    lock.lock()
                    let submitId = nextRequestID
                    nextRequestID += 1
                    pendingIDs.insert(submitId)
                    lock.unlock()
                    if let currentConn = currentConn {
                        let packet: [String: Any] = [
                            "id": submitId, "jsonrpc": "2.0", "method": "submit",
                            "params": ["id": minerId, "job_id": job.id, "nonce": hexNonce, "result": digest]
                        ]
                        networkQueue.async { [weak self] in self?.send(packet, on: currentConn) }
                    }
                }
                nonce &+= 1
                // One light-mode CPU worker, with pauses to reduce heat/battery load.
                Thread.sleep(forTimeInterval: 0.025)
                if Date().timeIntervalSince(tick) >= 5 {
                    let elapsed = max(Date().timeIntervalSince(tick), 0.1)
                    let observedRate = Double(attempts - lastReported) / elapsed
                    let observedHashes = attempts
                    lastReported = attempts
                    DispatchQueue.main.async {
                        self.rate = observedRate
                        self.hashes = observedHashes
                    }
                    tick = Date()
                }
            }
        }
    }

    // Stratum target is 4 or 8 little-endian bytes. For 4 bytes, expand
    // using the same conversion as XMRig's Job::setTarget.
    static func poolTarget(_ hex: String) -> UInt64? {
        guard let bytes = decodeHex(hex), bytes.count == 4 || bytes.count == 8 else { return nil }
        var value: UInt64 = 0
        for (index, byte) in bytes.enumerated() {
            value |= UInt64(byte) << UInt64(index * 8)
        }
        guard value > 0 else { return nil }
        if bytes.count == 8 { return value }
        let divisor = UInt64(UInt32.max) / value
        guard divisor > 0 else { return nil }
        return UInt64.max / divisor
    }

    static func isShare(hash: [UInt8], target: UInt64) -> Bool {
        guard hash.count == 32 else { return false }
        var result: UInt64 = 0
        for i in 0..<8 { result |= UInt64(hash[24 + i]) << UInt64(i * 8) }
        return result < target
    }

    static func decodeHex(_ text: String) -> Data? {
        guard text.count % 2 == 0, text.count <= 4096 else { return nil }
        let chars = Array(text.utf8)
        func digit(_ c: UInt8) -> UInt8? {
            switch c {
            case 48...57: return c - 48
            case 65...70: return c - 55
            case 97...102: return c - 87
            default: return nil
            }
        }
        var output = Data(capacity: chars.count / 2)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let a = digit(chars[i]), let b = digit(chars[i+1]) else { return nil }
            output.append(a * 16 + b)
        }
        return output
    }

    static func encodeHex(_ bytes: [UInt8]) -> String {
        let hex = Array("0123456789abcdef".utf8)
        var out = [UInt8]()
        out.reserveCapacity(bytes.count * 2)
        for b in bytes { out.append(hex[Int(b >> 4)]); out.append(hex[Int(b & 15)]) }
        return String(bytes: out, encoding: .utf8) ?? ""
    }
}
