import SwiftUI
import UIKit

private enum Palette {
    static let background = Color(red: 0.035, green: 0.052, blue: 0.115)
    static let panel = Color(red: 0.085, green: 0.12, blue: 0.21)
    static let cyan = Color(red: 0.25, green: 0.88, blue: 0.92)
    static let muted = Color(red: 0.62, green: 0.68, blue: 0.79)
}

struct DashboardView: View {
    @StateObject private var miner = DucoMiner()
    let account: WalletCredentials
    let onDisconnect: () -> Void
    @Environment(\.scenePhase) private var phase
    @State private var showHelp = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            RadialGradient(colors: [Palette.cyan.opacity(0.16), .clear],
                           center: .topTrailing, startRadius: 5, endRadius: 350)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if account.currency == .duinoCoin {
                        orb
                        HStack(spacing: 12) {
                            metric("PUISSANCE", String(format: "%.0f", miner.hashrate), "H/s", "bolt.fill")
                            metric("PARTS ACCEPTÉES", "\(miner.accepted)", "validées", "checkmark.seal.fill")
                        }
                        HStack(spacing: 12) {
                            metric("REFUSÉES", "\(miner.rejected)", "parts", "xmark.circle.fill")
                            metric("SESSION", formattedDuration, "écoulées", "clock.fill")
                        }
                    } else {
                        moneroNotice
                    }
                    controls
                    if account.currency == .duinoCoin {
                        statusCard
                    }
                    infoCard
                    Text(account.currency == .monero ? "Monero • Portefeuille associé • Prototype" : "Duino-Coin indépendant • Prototype")
                        .font(.system(size: 11)).foregroundColor(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 25)
                }
                .padding(.horizontal, 20).padding(.top, 24)
            }
        }
        .onChange(of: phase) { value in
            if value != .active { miner.stop(reason: "Arrêt : application en arrière-plan") }
        }
        .onChange(of: miner.isMining) { active in
            UIApplication.shared.isIdleTimerDisabled = active
        }
        .onDisappear {
            miner.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .alert(account.currency == .monero ? "Portefeuille Monero" : "Portefeuille DUCO", isPresented: $showHelp) {
            Button("Ouvrir le portefeuille") {
                UIApplication.shared.open(URL(string: account.currency == .monero
                    ? "https://cakewallet.com/" : "https://wallet.duinocoin.com/")!)
            }
            Button("Fermer", role: .cancel) {}
        } message: {
            Text(account.currency == .monero
                ? "Ton adresse publique XMR a été enregistrée localement. Elle ne donne aucun accès à tes fonds. Le moteur de minage Monero n'est pas encore développé et aucun XMR ne peut être gagné avec cette version."
                : "La configuration DUCO associe ton identifiant et ta clé de minage facultative. Ne donne jamais ton mot de passe ou ta phrase de récupération. Les mineurs communautaires non validés peuvent être bloqués par le réseau.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MINAGE").font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(4).foregroundColor(Palette.cyan)
                Text("iPhone").font(.system(size: 34, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: "cpu.fill")
                .font(.system(size: 22)).foregroundColor(Palette.cyan)
                .frame(width: 51, height: 51)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var orb: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Palette.cyan.opacity(miner.isMining ? 0.10 : 0.04))
                    .frame(width: 218, height: 218)
                Circle().stroke(Palette.cyan.opacity(0.28), lineWidth: 1)
                    .frame(width: 194, height: 194)
                Circle().stroke(Palette.cyan.opacity(0.17), lineWidth: 1)
                    .frame(width: 150, height: 150)
                Circle()
                    .fill(LinearGradient(colors: [Palette.cyan.opacity(0.65), Color.blue.opacity(0.1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 112, height: 112)
                    .blur(radius: 20)
                Image(systemName: miner.isMining ? "bolt.horizontal.circle.fill" : "circle.hexagongrid.fill")
                    .font(.system(size: 62, weight: .ultraLight))
                    .foregroundStyle(Palette.cyan)
                    .shadow(color: Palette.cyan.opacity(0.65), radius: 22)
            }
            Text(miner.isMining ? "CALCUL EN COURS" : "PRÊT POUR LE MINAGE")
                .font(.system(size: 12, weight: .bold)).tracking(2.5)
                .foregroundColor(Palette.cyan)
            Text("DUCO-S1 · Apple A10 Fusion")
                .font(.system(size: 12)).foregroundColor(Palette.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, _ value: String, _ unit: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: symbol).foregroundColor(Palette.cyan)
                Text(title).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(Palette.muted)
            Text(value).font(.system(size: 27, weight: .bold, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(unit).font(.system(size: 11)).foregroundColor(Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    }

    private var moneroNotice: some View {
        VStack(spacing: 14) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 46))
                .foregroundColor(Palette.cyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            Text("MONERO • RANDOMX")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundColor(Palette.cyan)
            Text("Portefeuille Cake Wallet associé")
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Le minage XMR n'est pas actif : il faut encore intégrer et tester un moteur RandomX léger, adapté aux 2 Go de RAM de l'iPhone 7. Aucun gain n'est produit dans ce mode.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundColor(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 10) {
                Image(systemName: "wallet.bifold.fill")
                    .foregroundColor(Palette.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.currency == .monero ? "ADRESSE MONERO (XMR)" : "COMPTE DUINO-COIN")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2).foregroundColor(Palette.muted)
                    Text(account.currency == .monero
                         ? String(account.username.prefix(12)) + "…" + String(account.username.suffix(9))
                         : account.username)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                }
                Spacer()
                Button("Changer") {
                    miner.stop(reason: "Changement de compte")
                    onDisconnect()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.cyan)
            }
            Rectangle().fill(Palette.muted.opacity(0.18)).frame(height: 1)
            Text(account.currency == .monero
                 ? "Ton adresse publique XMR est enregistrée sur cet iPhone. Les calculs Monero ne sont pas encore disponibles dans Minager."
                 : "Les gains éventuels sont envoyés au compte DUCO indiqué. L'application ne connaît pas ton mot de passe.")
                .font(.system(size: 12)).foregroundColor(Palette.muted)
            if account.currency == .duinoCoin {
                HStack(spacing: 12) {
                    Button {
                        UIApplication.shared.open(URL(string: "https://wallet.duinocoin.com/")!)
                    } label: {
                        Label("Portefeuille", systemImage: "arrow.up.right.square")
                            .font(.system(size: 13, weight: .medium))
                    }
                    Button(action: { showHelp = true }) {
                        Label("Aide", systemImage: "questionmark.circle")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .foregroundColor(Palette.cyan)
                .padding(.vertical, 2)
                Button {
                    if miner.isMining { miner.stop() }
                    else {
                        miner.start(username: account.username, miningKey: account.miningKey)
                    }
                } label: {
                    Label(miner.isMining ? "Arrêter le minage" : "Démarrer le minage",
                          systemImage: miner.isMining ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                }
                .foregroundColor(Palette.background)
                .background(miner.isMining ? Color.orange : Palette.cyan,
                            in: RoundedRectangle(cornerRadius: 15))
            } else {
                HStack(spacing: 12) {
                    Button {
                        UIApplication.shared.open(URL(string: "https://cakewallet.com/")!)
                    } label: {
                        Label("Cake Wallet", systemImage: "arrow.up.right.square")
                            .font(.system(size: 13, weight: .medium))
                    }
                    Button(action: { showHelp = true }) {
                        Label("Aide", systemImage: "questionmark.circle")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .foregroundColor(Palette.cyan)
                .padding(.vertical, 2)
                Label("Minage XMR : moteur RandomX à intégrer",
                      systemImage: "wrench.and.screwdriver.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18).background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform.path.ecg").foregroundColor(Palette.cyan)
            VStack(alignment: .leading, spacing: 5) {
                Text("ÉTAT DU RÉSEAU").font(.system(size: 10, weight: .bold))
                    .tracking(1.5).foregroundColor(Palette.muted)
                Text(miner.status).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 17))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("À SAVOIR", systemImage: "info.circle.fill")
                .font(.system(size: 11, weight: .bold)).foregroundColor(.orange)
            Text(account.currency == .monero
                 ? "La configuration de l'adresse XMR n'est pas un minage. Le moteur RandomX n'est pas inclus dans cette version et aucun solde ni rendement n'est simulé."
                 : "Ce compteur montre des calculs et des parts soumises au pool DUCO, pas des euros. Consulte le solde sur le portefeuille officiel.")
            Text("Un iPhone 7 peut chauffer et user sa batterie en calcul intensif. Ne le laisse pas branché et sans surveillance.")
        }
        .font(.system(size: 12)).foregroundColor(Palette.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private var formattedDuration: String {
        let m = miner.seconds / 60
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}
