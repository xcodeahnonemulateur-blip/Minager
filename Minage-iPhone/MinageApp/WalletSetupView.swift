import SwiftUI
import UIKit

struct WalletSetupView: View {
    let onConnect: (WalletCurrency, String, String) -> Bool
    @State private var address = ""
    @State private var scannerPresented = false
    @State private var photoPickerPresented = false
    @State private var errorMessage: String?

    private let background = Color(red: 0.035, green: 0.052, blue: 0.115)
    private let panel = Color(red: 0.085, green: 0.12, blue: 0.21)
    private let blue = Color(red: 0.25, green: 0.88, blue: 0.92)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            RadialGradient(colors: [blue.opacity(0.19), .clear],
                           center: .top, startRadius: 0, endRadius: 400).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 31))
                            .foregroundColor(blue)
                            .frame(width: 68, height: 68)
                            .background(panel, in: RoundedRectangle(cornerRadius: 19))
                        Spacer()
                        Text("iPHONE 7 · XMR").font(.caption).tracking(2).foregroundColor(blue)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minage iPhone")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Connecte ton portefeuille Cake Wallet en scannant son QR code Monero.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                    VStack(spacing: 13) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundColor(blue)
                            .frame(height: 115)
                        Text("Une seule configuration")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Nous enregistrons seulement ton adresse publique XMR. Aucun mot de passe ni mot secret n'est demandé.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Button { scannerPresented = true } label: {
                            Label("Scanner le QR code", systemImage: "camera.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .foregroundColor(background)
                        .background(blue, in: RoundedRectangle(cornerRadius: 14))
                        Button { photoPickerPresented = true } label: {
                            Label("Importer une photo du QR", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .foregroundColor(blue)
                        .background(background, in: RoundedRectangle(cornerRadius: 14))
                        Text("Même iPhone ? Dans Cake Wallet > Receive, enregistre une capture d'écran du QR, puis importe-la ici. Pour scanner par caméra, affiche le QR sur un autre écran.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .background(panel, in: RoundedRectangle(cornerRadius: 21))
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Ou coller l'adresse publique XMR")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                        TextField("Adresse XMR commençant par 4 ou 8", text: $address)
                            .font(.system(size: 12, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(15)
                            .background(panel, in: RoundedRectangle(cornerRadius: 12))
                        Button { save(address) } label: {
                            Label("Continuer avec cette adresse", systemImage: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .foregroundColor(blue)
                        .disabled(address.isEmpty)
                        if let errorMessage = errorMessage {
                            Text(errorMessage).foregroundColor(.orange)
                                .font(.system(size: 12))
                        }
                        Label("Minage expérimental sur processeur A10 · Batterie et chaleur à surveiller", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: 500)
                .padding(22)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $scannerPresented) {
            ZStack(alignment: .top) {
                MoneroQRScanner(onScan: { value in
                    scannerPresented = false
                    save(value)
                }, onError: { error in
                    scannerPresented = false
                    errorMessage = error
                }).ignoresSafeArea()
                Text("Cadre le QR de Cake Wallet")
                    .font(.headline)
                    .padding(14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 26)
            }
        }
        .sheet(isPresented: $photoPickerPresented) {
            MoneroQRPhotoPicker(onScan: { value in
                photoPickerPresented = false
                save(value)
            }, onError: { error in
                photoPickerPresented = false
                errorMessage = error
            })
        }
    }

    private func save(_ raw: String) {
        guard let clean = MoneroQRCode.address(from: raw) else {
            errorMessage = "Ce QR code ne contient pas une adresse publique Monero valide."
            return
        }
        address = clean
        if onConnect(.monero, clean, "") {
            errorMessage = nil
        } else {
            errorMessage = "Impossible d'enregistrer l'adresse dans le trousseau de l'iPhone."
        }
    }
}
