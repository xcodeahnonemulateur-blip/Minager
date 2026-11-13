import Foundation
import AVFoundation
import PhotosUI
import Vision
import UIKit
import SwiftUI

/// Accept ONLY a public XMR address, never a seed, private key or restore QR.
enum MoneroQRCode {
    static let base58 = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    static func address(from raw: String) -> String? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidate = input
        if input.lowercased().hasPrefix("monero:") {
            candidate = String(input.dropFirst(7))
            if candidate.hasPrefix("//") { candidate = String(candidate.dropFirst(2)) }
            candidate = String(candidate.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        } else if input.lowercased().hasPrefix("cakewallet:monero?") {
            guard let components = URLComponents(string: input),
                  let publicValue = components.queryItems?.first(where: { $0.name == "address" })?.value else {
                return nil
            }
            candidate = publicValue
        }
        guard candidate.count == 95,
              candidate.hasPrefix("4") || candidate.hasPrefix("8"),
              candidate.allSatisfy({ base58.contains($0) }) else { return nil }
        return candidate
    }
}

struct MoneroQRScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> CameraController {
        let c = CameraController()
        c.onScan = onScan
        c.onError = onError
        return c
    }
    func updateUIViewController(_ uiViewController: CameraController, context: Context) {}
}

final class CameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onError: ((String) -> Void)?
    private var session: AVCaptureSession?
    private var preview: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.setupCamera() }
                    else { self.onError?("Autorise la caméra dans Réglages pour scanner le QR.") }
                }
            }
        default:
            onError?("Autorise la caméra dans Réglages pour scanner le QR.")
        }
    }

    private func setupCamera() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            onError?("Caméra arrière indisponible")
            return
        }
        let session = AVCaptureSession()
        guard session.canAddInput(input) else { onError?("Impossible de lire la caméra"); return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { onError?("Scan QR indisponible"); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        self.preview = preview
        self.session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didScan else { return }
        for item in metadataObjects {
            guard let scanned = (item as? AVMetadataMachineReadableCodeObject)?.stringValue else { continue }
            if let address = MoneroQRCode.address(from: scanned) {
                didScan = true
                session?.stopRunning()
                onScan?(address)
                break
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = session, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
        }
    }
}

/// Photo picker allows importing a Cake Wallet QR screenshot on the SAME phone.
struct MoneroQRPhotoPicker: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = 1
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MoneroQRPhotoPicker
        init(_ parent: MoneroQRPhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
            _ = item.loadObject(ofClass: UIImage.self) { object, error in
                guard let image = object as? UIImage, let cg = image.cgImage else {
                    DispatchQueue.main.async { self.parent.onError("Impossible de lire cette image") }
                    return
                }
                let request = VNDetectBarcodesRequest()
                request.symbologies = [.qr]
                do {
                    try VNImageRequestHandler(cgImage: cg).perform([request])
                    let address = request.results?.compactMap { MoneroQRCode.address(from: $0.payloadStringValue ?? "") }.first
                    DispatchQueue.main.async {
                        if let address = address { self.parent.onScan(address) }
                        else { self.parent.onError("Aucun QR Monero valide dans cette image") }
                    }
                } catch {
                    DispatchQueue.main.async { self.parent.onError("Lecture QR échouée") }
                }
            }
        }
    }
}
