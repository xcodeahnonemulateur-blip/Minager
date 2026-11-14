import SwiftUI
import UIKit
import Combine

@MainActor
final class PoolTransferStats: ObservableObject {
    @Published var minimumPayoutXMR: Double?
    @Published var defaultPayoutXMR: Double?
    @Published var unpaidXMR: Double?
    @Published var paidXMR: Double?
    @Published var walletThresholdXMR: Double?
    @Published var status = "Statistiques du pool non chargées"
    @Published var updating = false

    func refresh(address: String) {
        guard !updating else { return }
        updating = true
        status = "Lecture des statistiques officielles…"
        Task {
            defer { updating = false }
            do {
                let configURL = URL(string: "https://api.hashvault.pro/v3/monero")!
                var request = URLRequest(url: configURL)
                request.timeoutInterval = 12
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let config = root["config"] as? [String: Any],
                      let payout = config["payout"] as? [String: Any] else {
                    throw NSError(domain: "PoolStats", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Configuration de paiement indisponible"])
                }
                let atomic = 1_000_000_000_000.0
                if let minimum = (payout["minimum"] as? NSNumber)?.doubleValue {
                    minimumPayoutXMR = minimum / atomic
                }
                if let fallback = (payout["defaultWallet"] as? NSNumber)?.doubleValue {
                    defaultPayoutXMR = fallback / atomic
                }
                status = "Seuils du pool mis à jour"
            } catch {
                status = "Impossible de joindre l'API du pool : \(error.localizedDescription)"
            }
            // If the public wallet stats API has never seen this address it may
            // return 404. Do not turn that into a misleading 0 XMR balance.
            guard let walletURL = URL(string: "https://api.hashvault.pro/v3/monero/wallet/\(address)/stats?chart=false") else { return }
            do {
                var request = URLRequest(url: walletURL)
                request.timeoutInterval = 12
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                // Use only explicit documented-style atomic-unit fields.
                let wallet = (json["wallet"] as? [String: Any]) ??
                             (json["result"] as? [String: Any]) ?? json
                if let balance = (wallet["balance"] as? NSNumber)?.doubleValue {
                    unpaidXMR = balance / 1_000_000_000_000.0
                }
                if let paid = (wallet["paid"] as? NSNumber)?.doubleValue {
                    paidXMR = paid / 1_000_000_000_000.0
                }
                if let threshold = (wallet["thold"] as? NSNumber)?.doubleValue {
                    walletThresholdXMR = threshold / 1_000_000_000_000.0
                } else if let threshold = (wallet["threshold"] as? NSNumber)?.doubleValue {
                    walletThresholdXMR = threshold / 1_000_000_000_000.0
                }
                status = "Données fournies par HashVault, pas par Cake Wallet"
            } catch {
                // No invented zero balance when a wallet has no pool record.
            }
        }
    }
}

struct TransferPanel: View {
    let address: String
    @StateObject private var stats = PoolTransferStats()

    private let background = Color(red: 0.965, green: 0.973, blue: 0.985)
    private let ink = Color(red: 0.10, green: 0.15, blue: 0.25)
    private let blue = Color(red: 0.09, green: 0.36, blue: 0.91)
    private let secondary = Color(red: 0.40, green: 0.45, blue: 0.54)

    // Only a wallet-specific threshold is authoritative. The pool default
    // is an illustration, never a confirmation of a specific wallet's settings.
    private var referenceThreshold: Double? {
        stats.walletThresholdXMR ?? stats.defaultPayoutXMR
    }

    private var proportion: Double? {
        guard let balance = stats.unpaidXMR,
              let threshold = referenceThreshold, threshold > 0 else { return nil }
        return min(max(balance / threshold, 0), 1)
    }

    private var paymentExplanation: String {
        guard let balance = stats.unpaidXMR else {
            return "Le pool n'a pas encore fourni ton solde. Aucun montant n'est inventé."
        }
        guard let threshold = referenceThreshold else {
            return "Solde reçu, mais seuil de paiement non disponible."
        }
        if balance >= threshold {
            return stats.walletThresholdXMR != nil
                ? "Seuil déclaré atteint. Le pool vérifiera les fonds disponibles et déclenchera le paiement selon ses règles."
                : "Le solde dépasse le seuil par défaut. Confirme ton seuil personnel sur HashVault : il peut être différent."
        }
        return "Il manque encore \(String(format: "%.8f", threshold - balance)) XMR pour le seuil \(stats.walletThresholdXMR != nil ? "du portefeuille" : "par défaut")."
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transfert vers Cake Wallet")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundColor(ink)

                    Label("Versements automatiques du pool", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(blue)
                    Text("Tes XMR restent sur HashVault jusqu'au paiement. Après le seuil, HashVault les envoie à l'adresse publique Cake Wallet déjà connectée.")
                        .font(.system(size: 13))
                        .foregroundColor(secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("GAINS EN ATTENTE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(secondary)

                        Text(stats.unpaidXMR.map { String(format: "%.8f XMR", $0) } ?? "Non disponible")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(ink)
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        if let proportion = proportion {
                            ProgressView(value: proportion)
                                .accentColor(blue)
                            HStack {
                                Text("Progression indicative")
                                Spacer()
                                Text("\(Int(proportion * 100)) %")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(secondary)
                        }
                        Text(paymentExplanation)
                            .font(.system(size: 12))
                            .foregroundColor(secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Seuil minimum technique")
                            Spacer(minLength: 6)
                            Text(stats.minimumPayoutXMR.map { String(format: "%.6f XMR", $0) } ?? "Inconnu")
                                .fontWeight(.semibold)
                        }
                        Divider()
                        HStack {
                            Text(stats.walletThresholdXMR == nil ? "Seuil par défaut" : "Seuil de ton compte")
                            Spacer(minLength: 6)
                            Text(referenceThreshold.map { String(format: "%.6f XMR", $0) } ?? "Inconnu")
                                .fontWeight(.semibold)
                        }
                        if stats.walletThresholdXMR == nil {
                            Text("Le seuil personnel n'a pas été confirmé. Modifiable sur le site du pool.")
                                .font(.system(size: 11))
                                .foregroundColor(secondary)
                        }
                        if let sent = stats.paidXMR {
                            Divider()
                            HStack {
                                Text("Total déjà versé par le pool")
                                Spacer(minLength: 6)
                                Text(String(format: "%.8f XMR", sent))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(ink)
                    .padding(17)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

                    Button {
                        // Copy only the public address, not any secret credentials.
                        UIPasteboard.general.string = address
                        UIApplication.shared.open(URL(string: "https://hashvault.pro/monero/dashboard")!)
                    } label: {
                        Label("Gérer le seuil et les paiements", systemImage: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .foregroundColor(.white)
                    .background(blue, in: RoundedRectangle(cornerRadius: 15))

                    Text("Ton adresse XMR est copiée pour la coller sur HashVault. Aucun paiement n'est lancé par ce bouton : c'est le pool qui effectue les versements.")
                        .font(.system(size: 12))
                        .foregroundColor(secondary)

                    Button {
                        stats.refresh(address: address)
                    } label: {
                        Label(stats.updating ? "Actualisation…" : "Actualiser les gains", systemImage: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .disabled(stats.updating)
                    .foregroundColor(blue)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))

                    Text(stats.status)
                        .font(.system(size: 12))
                        .foregroundColor(secondary)
                    Text("Les paiements ne sont possibles que si le pool a effectivement attribué des récompenses. L'application ne connaît pas les clés privées Cake Wallet.")
                        .font(.system(size: 11))
                        .foregroundColor(secondary)
                }
                .padding(18)
            }
        }
        .onAppear { stats.refresh(address: address) }
    }
}
