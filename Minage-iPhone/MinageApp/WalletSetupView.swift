import SwiftUI
import UIKit

/// Select a chain and record a PUBLIC mining-reward destination.
/// This does not authorize transactions or turn on a miner.
struct WalletSetupView: View {
    let onConnect: (WalletCurrency, String, String) -> Bool

    @State private var currency: WalletCurrency = .monero
    @State private var identifier = ""
    @State private var miningKey = ""
    @State private var errorMessage: String?

    private let bg = Color(red: 0.035, green: 0.052, blue: 0.115)
    private let surface = Color(red: 0.085, green: 0.12, blue: 0.21)
    private let accent = Color(red: 0.25, green: 0.88, blue: 0.92)
    private let subtle = Color(red: 0.65, green: 0.70, blue: 0.80)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.20), .clear],
                           center: .top, startRadius: 0, endRadius: 350)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 36))
                        .foregroundColor(accent)
                        .frame(width: 76, height: 76)
                        .background(surface, in: RoundedRectangle(cornerRadius: 22))
                        .padding(.bottom, 6)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bienvenue sur")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(subtle)
                        Text("Minage iPhone")
                            .font(.system(size: 33, weight: .bold, design: .rounded))
                        Text("Choisis ton portefeuille de destination, sans donner tes identifiants secrets.")
                            .font(.system(size: 14))
                            .foregroundColor(subtle)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        Label("CHOISIR UNE CRYPTOMONNAIE", systemImage: "wallet.bifold.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accent)
                        Picker("Cryptomonnaie", selection: $currency) {
                            ForEach(WalletCurrency.allCases) { coin in
                                Text(coin == .monero ? "Monero XMR" : "DUCO").tag(coin)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: currency) { _ in
                            identifier = ""
                            miningKey = ""
                            errorMessage = nil
                        }
                        if currency == .monero {
                            Text("Compatible avec ton Cake Wallet")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(accent)
                            Text("Ouvre Cake Wallet → Monero → Receive. Copie l'adresse publique XMR (95 caractères).")
                                .font(.system(size: 12))
                                .foregroundColor(subtle)
                            TextField("Colle ton adresse Monero XMR", text: $identifier)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .autocorrectionDisabled()
                                .font(.system(size: 13, design: .monospaced))
                                .padding(14)
                                .background(bg, in: RoundedRectangle(cornerRadius: 12))
                            Text("Le moteur RandomX n'est pas encore disponible. Cette étape associe seulement l'adresse publique à Minager, sans produire de XMR.")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Identifiant Duino-Coin")
                                .font(.system(size: 13, weight: .semibold))
                            TextField("Ton identifiant DUCO", text: $identifier)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(bg, in: RoundedRectangle(cornerRadius: 12))
                            Text("Mining key (facultative)")
                                .font(.system(size: 13, weight: .semibold))
                            SecureField("La clé de minage, pas le mot de passe", text: $miningKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(bg, in: RoundedRectangle(cornerRadius: 12))
                            Text("Le moteur DUCO reste expérimental et n'est pas validé par le réseau.")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                        Button(action: connect) {
                            Label("Enregistrer le portefeuille", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                        }
                        .foregroundColor(bg)
                        .background(accent, in: RoundedRectangle(cornerRadius: 14))
                        .disabled(identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.65 : 1)
                    }
                    .padding(18)
                    .background(surface, in: RoundedRectangle(cornerRadius: 21))
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            UIApplication.shared.open(URL(string: currency == .monero
                                ? "https://cakewallet.com/" : "https://wallet.duinocoin.com/")!)
                        } label: {
                            Label(currency == .monero ? "Site officiel Cake Wallet" : "Portefeuille DUCO",
                                  systemImage: "arrow.up.right.square")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(accent)
                        Text("Jamais de phrase de récupération, jamais de mot de passe. Les données enregistrées restent dans le trousseau sécurisé iOS.")
                            .font(.system(size: 11))
                            .foregroundColor(subtle)
                    }
                }
                .frame(maxWidth: 480, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func connect() {
        if onConnect(currency, identifier, miningKey) {
            errorMessage = nil
            miningKey = ""
        } else {
            errorMessage = currency == .monero
                ? "Adresse XMR invalide : elle doit contenir 95 caractères et commencer par 4 ou 8."
                : "Vérifie ton identifiant DUCO et ta Mining key."
        }
    }
}
