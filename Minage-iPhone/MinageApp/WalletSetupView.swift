import SwiftUI
import UIKit

// Scan a PUBLIC Cake Wallet address. Private keys are never imported.
struct WalletSetupView: View {
    let onConnect: (WalletCurrency, String, String) -> Bool
    @State private var address = ""
    @State private var scannerPresented = false
    @State private var photoPickerPresented = false
    @State private var errorMessage: String?

    private let background = Color(red: 0.965, green: 0.973, blue: 0.985)
    private let blue = Color(red: 0.09, green: 0.36, blue: 0.91)
    private let ink = Color(red: 0.10, green: 0.15, blue: 0.25)
    private let secondary = Color(red: 0.40, green: 0.45, blue: 0.54)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 30))
                            .foregroundColor(blue)
                            .frame(width: 56, height: 56)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Minager")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(ink)
                            Text("Monero XMR · iPhone 7")
                                .font(.system(size: 13))
                                .foregroundColor(secondary)
                        }
                    }
                    .padding(.top, 18)

                    Text("Connecter Cake Wallet")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(ink)
                    Text("Scanne le QR code « Receive » de Cake Wallet. C'est seulement ton adresse publique, pas tes mots secrets.")
                        .font(.system(size: 14))
                        .foregroundColor(secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 65))
                            .foregroundColor(blue)
                            .padding(.vertical, 14)

                        Button { scannerPresented = true } label: {
                            Label("Scanner avec la caméra", systemImage: "camera.viewfinder")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .foregroundColor(.white)
                        .background(blue, in: RoundedRectangle(cornerRadius: 15))

                        Button { photoPickerPresented = true } label: {
                            Label("Importer le QR depuis Photos", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .foregroundColor(blue)
                        .background(background, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(18)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

                    Text("Si Cake Wallet est sur ce même iPhone, fais une capture du QR dans « Receive » et utilise « Importer le QR ».")
                        .font(.system(size: 12))
                        .foregroundColor(secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Ou colle l'adresse XMR ici", text: $address)
                        .font(.system(size: 13, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 13))

                    Button("Connecter cette adresse") { save(address) }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(blue)
                        .disabled(address.isEmpty)
                        .padding(.vertical, 3)

                    if let errorMessage = errorMessage {
                        Text(errorMessage).font(.system(size: 12)).foregroundColor(.orange)
                    }
                    Text("Les calculs commencent au premier plan après la connexion. L'iPhone peut chauffer et les gains ne sont pas garantis.")
                        .font(.system(size: 12))
                        .foregroundColor(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
                .frame(maxWidth: 480)
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
                })
                .ignoresSafeArea()
                Text("Cadre le QR Monero")
                    .font(.headline)
                    .padding(13)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 24)
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

    private func save(_ text: String) {
        guard let clean = MoneroQRCode.address(from: text) else {
            errorMessage = "Adresse Monero incorrecte. Scanne le QR « Receive » de Cake Wallet."
            return
        }
        address = clean
        if onConnect(.monero, clean, "") {
            errorMessage = nil
        } else {
            errorMessage = "Impossible de mémoriser cette adresse sur l'iPhone."
        }
    }
}
