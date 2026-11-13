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
    private let bg = Color(red: 0.035, green: 0.052, blue: 0.115)
    private let surface = Color(red: 0.09, green: 0.12, blue: 0.22)
    private let cyan = Color(red: 0.24, green: 0.88, blue: 0.94)
    private let muted = Color(red: 0.62, green: 0.68, blue: 0.79)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TRANSFERT").font(.system(size: 11, weight: .bold))
                                .tracking(3).foregroundColor(cyan)
                            Text("Vers Cake Wallet")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 39)).foregroundColor(cyan)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SOLDE EN ATTENTE AU POOL")
                            .font(.system(size: 11, weight: .bold)).tracking(1.7)
                            .foregroundColor(muted)
                        Text(stats.unpaidXMR.map { String(format: "%.8f XMR", $0) } ?? "Non disponible")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Le solde Cake Wallet est séparé du solde en attente au pool. Les gains et transferts ne sont jamais simulés.")
                            .font(.system(size: 12))
                            .foregroundColor(muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(surface, in: RoundedRectangle(cornerRadius: 20))
                    HStack(spacing: 12) {
                        statCard("SEUIL MINIMAL", stats.minimumPayoutXMR.map { String(format: "%.4f", $0) } ?? "…")
                        statCard("SEUIL PAR DÉFAUT", stats.defaultPayoutXMR.map { String(format: "%.3f", $0) } ?? "…")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Comment marche le transfert ?", systemImage: "info.circle.fill")
                            .foregroundColor(cyan).font(.system(size: 14, weight: .semibold))
                        Text("1. Le pool vérifie les parts de minage acceptées et accumule les gains éventuels.")
                        Text("2. Lorsque le seuil de versement fixé par le pool est atteint, il paie directement ton adresse Cake Wallet.")
                        Text("3. Tu peux consulter et modifier le seuil sur le site du pool, si celui-ci l'autorise.")
                        Text("Notre application n'a aucun accès à tes clés privées et ne peut pas déclencher un paiement que le pool n'autorise pas.")
                            .foregroundColor(.orange)
                    }
                    .font(.system(size: 13))
                    .padding(17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(surface, in: RoundedRectangle(cornerRadius: 18))
                    Button {
                        UIApplication.shared.open(URL(string: "https://hashvault.pro/monero")!)
                    } label: {
                        Label("Gérer le transfert sur HashVault", systemImage: "arrow.up.right.square")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .foregroundColor(bg)
                    .background(cyan, in: RoundedRectangle(cornerRadius: 15))
                    Button { stats.refresh(address: address) } label: {
                        Label("Actualiser les gains et seuils", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .disabled(stats.updating)
                    .foregroundColor(cyan)
                    Text(stats.status).font(.system(size: 12)).foregroundColor(muted)
                    Text("Le pool publie un seuil technique minimum et un seuil par défaut qui peuvent être différents. Les valeurs sont lues en direct et peuvent changer.")
                        .font(.system(size: 11)).foregroundColor(muted)
                }
                .padding(20)
            }
        }
        .onAppear { stats.refresh(address: address) }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(.system(size: 10, weight: .bold))
                .foregroundColor(muted)
            Text(value).font(.system(size: 22, weight: .bold))
                .minimumScaleFactor(0.7).lineLimit(1)
            Text("XMR").font(.system(size: 11)).foregroundColor(muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(surface, in: RoundedRectangle(cornerRadius: 18))
    }
}
