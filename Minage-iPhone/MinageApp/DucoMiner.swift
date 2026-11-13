import Foundation
import Combine
import CryptoKit
import Network

/// True CPU Duino-Coin (DUCO-S1) prototype.
/// Matches the open-source official PC miner job and share messages.
/// This is not an exchange, wallet, fake balance, or background miner.
final class DucoMiner: ObservableObject {
    @Published private(set) var isMining = false
    @Published private(set) var status = "Entre ton identifiant Duino-Coin pour commencer."
    @Published private(set) var hashrate = 0.0
    @Published private(set) var accepted = 0
    @Published private(set) var rejected = 0
    @Published private(set) var seconds = 0

    private let worker = DispatchQueue(label: "fr.minageiphone.miner", qos: .utility)
    private let lock = NSLock()
    private var shouldStop = true
    private var connection: NWConnection?
    private var sessionID = UUID()

    func start(username: String, miningKey: String) {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty,
              user.range(of: "^[a-zA-Z0-9_\\-]{2,40}$", options: .regularExpression) != nil else {
            status = "Identifiant invalide. Utilise le nom de ton compte DUCO."
            return
        }
        guard !isMining else { return }
        lock.lock()
        shouldStop = false
        sessionID = UUID()
        let id = sessionID
        lock.unlock()
        isMining = true
        status = "Recherche d'un pool officiel…"
        hashrate = 0
        accepted = 0
        rejected = 0
        seconds = 0
        worker.async { [weak self] in
            self?.run(user: user, key: miningKey.isEmpty ? "None" : miningKey, id: id)
        }
    }

    func stop(reason: String = "Minage arrêté") {
        lock.lock()
        shouldStop = true
        connection?.cancel()
        connection = nil
        lock.unlock()
        DispatchQueue.main.async {
            self.isMining = false
            self.hashrate = 0
            self.status = reason
        }
    }

    private func running(_ id: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !shouldStop && sessionID == id
    }

    private func update(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    private struct Pool: Decodable {
        let success: Bool
        let ip: String
        let port: Int
    }

    private func fetchPool() throws -> Pool {
        var request = URLRequest(url: URL(string: "https://server.duinocoin.com/getPool")!)
        request.timeoutInterval = 12
        let semaphore = DispatchSemaphore(value: 0)
        var output: Result<Data, Error> = .failure(NSError(domain: "network", code: 1))
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { output = .failure(error) }
            else if let data = data { output = .success(data) }
            semaphore.signal()
        }.resume()
        guard semaphore.wait(timeout: .now() + 15) == .success else {
            throw MinerError.message("Recherche du pool expirée")
        }
        let pool = try JSONDecoder().decode(Pool.self, from: output.get())
        guard pool.success, pool.port > 0, pool.port < 65536 else {
            throw MinerError.message("Aucun pool disponible")
        }
        return pool
    }

    private func connect(_ pool: Pool, id: UUID) throws -> NWConnection {
        guard let port = NWEndpoint.Port(rawValue: UInt16(pool.port)) else {
            throw MinerError.message("Port incorrect")
        }
        let conn = NWConnection(host: NWEndpoint.Host(pool.ip), port: port, using: .tcp)
        let ready = DispatchSemaphore(value: 0)
        var connected = false
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connected = true
                ready.signal()
            case .failed(_), .cancelled:
                ready.signal()
            default: break
            }
        }
        lock.lock()
        connection = conn
        lock.unlock()
        conn.start(queue: DispatchQueue(label: "fr.minageiphone.socket"))
        guard ready.wait(timeout: .now() + 10) == .success, connected, running(id) else {
            conn.cancel()
            throw MinerError.message("Connexion au pool impossible")
        }
        return conn
    }

    private func receive(_ conn: NWConnection) throws -> String {
        let gate = DispatchSemaphore(value: 0)
        var result: String?
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
            if let data = data { result = String(data: data, encoding: .utf8) }
            gate.signal()
        }
        guard gate.wait(timeout: .now() + 15) == .success, let result = result else {
            throw MinerError.message("Le pool ne répond pas")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send(_ message: String, on conn: NWConnection) throws {
        let gate = DispatchSemaphore(value: 0)
        var failure: NWError?
        conn.send(content: Data(message.utf8), completion: .contentProcessed { error in
            failure = error
            gate.signal()
        })
        guard gate.wait(timeout: .now() + 10) == .success, failure == nil else {
            throw MinerError.message("Envoi au pool impossible")
        }
    }

    private func run(user: String, key: String, id: UUID) {
        let since = Date()
        while running(id) {
            if ProcessInfo.processInfo.thermalState == .serious ||
               ProcessInfo.processInfo.thermalState == .critical {
                stop(reason: "Arrêt de sécurité : iPhone trop chaud")
                return
            }
            var socket: NWConnection?
            do {
                let pool = try fetchPool()
                guard running(id) else { break }
                socket = try connect(pool, id: id)
                guard let socket = socket else { break }
                _ = try receive(socket) // Pool's protocol version banner.
                update { self.status = "Connecté • Recherche de parts DUCO…" }

                while running(id) {
                    try send("JOB,\(user),MEDIUM,\(key),", on: socket)
                    let fields = try receive(socket).split(separator: ",", omittingEmptySubsequences: false)
                    guard fields.count == 3,
                          let difficulty = Int(fields[2]),
                          (1...200000).contains(difficulty),
                          let target = Self.decodeHex(String(fields[1])) else {
                        throw MinerError.message("Réponse de travail incompatible : \(fields.prefix(2).joined(separator: ","))")
                    }
                    let outcome = findNonce(previous: String(fields[0]),
                                            target: target,
                                            difficulty: difficulty, id: id)
                    guard running(id) else { break }
                    guard let nonce = outcome.nonce else {
                        throw MinerError.message("Aucun résultat à difficulté \(difficulty)")
                    }
                    let minerName = "Minage iPhone 0.1"
                    try send("\(nonce),\(Int(outcome.rate)),\(minerName),iPhone7,,\(id.uuidString)", on: socket)
                    let response = try receive(socket)
                    update {
                        self.hashrate = outcome.rate
                        self.seconds = Int(Date().timeIntervalSince(since))
                        if response.hasPrefix("GOOD") || response.hasPrefix("BLOCK") {
                            self.accepted += 1
                            self.status = "Part acceptée par le pool ✓"
                        } else {
                            self.rejected += 1
                            self.status = "Part refusée : \(response.prefix(80))"
                        }
                    }
                }
                socket.cancel()
            } catch {
                socket?.cancel()
                guard running(id) else { break }
                update { self.status = "Réseau : \(error.localizedDescription) • nouvelle tentative" }
                for _ in 0..<8 {
                    if !running(id) { break }
                    Thread.sleep(forTimeInterval: 1)
                }
            }
        }
    }

    private func findNonce(previous: String, target: [UInt8], difficulty: Int, id: UUID)
    -> (nonce: Int?, rate: Double) {
        guard target.count == 20 else { return (nil, 0) }
        let base = Data(previous.utf8)
        let start = Date()
        var checked = 0
        for nonce in 0...(difficulty * 100) {
            if nonce % 512 == 0 {
                if !running(id) { return (nil, 0) }
                if ProcessInfo.processInfo.thermalState == .serious ||
                   ProcessInfo.processInfo.thermalState == .critical {
                    stop(reason: "Arrêt de sécurité : iPhone trop chaud")
                    return (nil, 0)
                }
                // Small duty cycle: intentionally less heat than continuous 100% CPU.
                Thread.sleep(forTimeInterval: 0.004)
            }
            var candidate = base
            candidate.append(contentsOf: String(nonce).utf8)
            checked += 1
            if Array(Insecure.SHA1.hash(data: candidate)) == target {
                let elapsed = max(Date().timeIntervalSince(start), 0.001)
                return (nonce, Double(checked) / elapsed)
            }
        }
        return (nil, 0)
    }

    private static func decodeHex(_ hex: String) -> [UInt8]? {
        guard hex.count == 40 else { return nil }
        var values: [UInt8] = []
        var cursor = hex.startIndex
        while cursor < hex.endIndex {
            let end = hex.index(cursor, offsetBy: 2)
            guard let byte = UInt8(hex[cursor..<end], radix: 16) else { return nil }
            values.append(byte)
            cursor = end
        }
        return values
    }

    private enum MinerError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case let .message(message) = self { return message }
            return nil
        }
    }
}
