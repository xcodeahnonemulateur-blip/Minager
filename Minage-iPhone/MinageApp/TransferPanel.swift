import SwiftUI
import UIKit
import Combine

@MainActor
final class PoolTransferStats: ObservableObject {
    @Published var minimumPayoutXMR: Double?
    @Published var defaultPayoutXMR: Double?
    @Published var unpaidXMR: Double?
    @Published var paidXMR: Double?
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

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transferts")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(ink)
                    Text("Tes récompenses Monero sont versées par le pool directement vers Cake Wallet.")
                        .font(.system(size: 13))
                        .foregroundColor(secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gains en attente au pool")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(secondary)
                        Text(stats.unpaidXMR.map { String(format: "%.8f XMR", $0) } ?? "Non disponible")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundColor(ink)
                            .monospacedDigit()
                        Text("Données du pool, pas ton solde Cake Wallet")
                            .font(.system(size: 11))
                            .foregroundColor(secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Seuil de paiement minimum")
                                .font(.system(size: 13))
                                .foregroundColor(secondary)
                            Spacer()
                            Text(stats.minimumPayoutXMR.map { String(format: "%.6f XMR", $0) } ?? "Indisponible")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ink)
                        }
                        Divider()
                        HStack {
                            Text("Seuil par défaut")
                                .font(.system(size: 13))
                                .foregroundColor(secondary)
                            Spacer()
                            Text(stats.defaultPayoutXMR.map { String(format: "%.6f XMR", $0) } ?? "Indisponible")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ink)
                        }
                    }
                    .padding(17)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))

                    Button {
                        UIApplication.shared.open(URL(string: "https://hashvault.pro/monero")!)
                    } label: {
                        Label("Voir mes paiements sur HashVault", systemImage: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .foregroundColor(.white)
                    .background(blue, in: RoundedRectangle(cornerRadius: 15))

                    Button {
                        stats.refresh(address: address)
                    } label: {
                        Label(stats.updating ? "Actualisation…" : "Actualiser mes gains", systemImage: "arrow.clockwise")
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
                    Text("Le pool décide quand il paie. Minager ne peut pas transférer des XMR avant le seuil et ne connaît pas tes clés privées.")
                        .font(.system(size: 12))
                        .foregroundColor(secondary)
                }
                .padding(18)
            }
        }
        .onAppear { stats.refresh(address: address) }
    }
}
