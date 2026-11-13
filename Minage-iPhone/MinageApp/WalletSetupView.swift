import SwiftUI
import UIKit

/// First-launch setup. Does not log in to Duino-Coin or ask for a wallet password.
struct WalletSetupView: View {
    let onConnect: (String, String) -> Bool

    @State private var username = ""
    @State private var miningKey = ""
    @State private var errorMessage: String?

    private let bg = Color(red: 0.035, green: 0.052, blue: 0.115)
    private let surface = Color(red: 0.085, green: 0.12, blue: 0.21)
    private let accent = Color(red: 0.25, green: 0.88, blue: 0.92)
    private let subtle = Color(red: 0.65, green: 0.70, blue: 0.80)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.19), .clear],
                           center: .top, startRadius: 0, endRadius: 340)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    logo
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Bienvenue sur").foregroundColor(subtle)
                            .font(.system(size: 15, weight: .medium))
                        Text("Minage iPhone")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Associe ton compte Duino-Coin pour attribuer tes récompenses de minage.")
                            .font(.system(size: 14))
                            .foregroundColor(subtle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("TON COMPTE DUINO-COIN", systemImage: "wallet.bifold.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accent)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Identifiant du portefeuille")
                                .font(.system(size: 13, weight: .semibold))
                            TextField("Exemple : mon_compte_DUCO", text: $username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(bg, in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("Identifiant Duino-Coin")
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Mining key (facultative)")
                                .font(.system(size: 13, weight: .semibold))
                            SecureField("Clé de minage, si tu en as une", text: $miningKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(bg, in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("Clé de minage facultative")
                            Text("Ce n'est PAS ton mot de passe. Si tu n'as pas activé de Mining key, laisse vide.")
                                .font(.system(size: 11))
                                .foregroundColor(subtle)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button(action: connect) {
                            Label("Continuer", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                        }
                        .background(accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(bg)
                        .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                    }
                    .padding(18)
                    .background(surface, in: RoundedRectangle(cornerRadius: 21))
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Pas encore de compte DUCO ?", systemImage: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Button {
                            UIApplication.shared.open(URL(string: "https://wallet.duinocoin.com/")!)
                        } label: {
                            Label("Ouvrir le portefeuille officiel", systemImage: "arrow.up.right.square")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(accent)
                        Text("Tes informations de minage restent dans le trousseau sécurisé de cet iPhone. Aucun mot de passe ni phrase de récupération ne doit être saisi.")
                            .font(.system(size: 11))
                            .foregroundColor(subtle)
                        Text("Attention : ce mineur expérimental n'est pas encore approuvé par le réseau DUCO et peut entraîner un blocage de compte.")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .padding(2)
                    Spacer(minLength: 16)
                }
                .frame(maxWidth: 480, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var logo: some View {
        Image(systemName: "bolt.horizontal.circle.fill")
            .font(.system(size: 42))
            .foregroundColor(accent)
            .frame(width: 80, height: 80)
            .background(surface, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: accent.opacity(0.2), radius: 25)
            .padding(.bottom, 4)
    }

    private func connect() {
        if onConnect(username, miningKey) {
            errorMessage = nil
            miningKey = ""
        } else {
            errorMessage = "Identifiant ou clé incorrectement formaté, ou enregistrement impossible. Vérifie tes informations DUCO."
        }
    }
}
