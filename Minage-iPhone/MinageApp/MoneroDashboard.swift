import SwiftUI
import UIKit

// Main screen designed for the 4.7-inch iPhone 7: one action, genuine status.
struct MoneroDashboard: View {
    let address: String
    let onDisconnect: () -> Void
    @StateObject private var miner = MoneroMineEngine()
    @StateObject private var rewards = PoolTransferStats()
    @State private var selectedTab = 0
    @State private var wantsMining = true
    @State private var hasAppeared = false
    @Environment(\.scenePhase) private var scenePhase

    private let background = Color(red: 0.965, green: 0.973, blue: 0.985)
    private let ink = Color(red: 0.10, green: 0.15, blue: 0.25)
    private let blue = Color(red: 0.09, green: 0.36, blue: 0.91)
    private let secondary = Color(red: 0.40, green: 0.45, blue: 0.54)
    private let card = Color.white

    var body: some View {
        TabView(selection: $selectedTab) {
            miningScreen
                .tabItem { Label("Minage", systemImage: "cpu") }
                .tag(0)

            TransferPanel(address: address)
                .tabItem { Label("Transfert", systemImage: "arrow.left.arrow.right") }
                .tag(1)

            settingsScreen
                .tabItem { Label("Compte", systemImage: "wallet.bifold") }
                .tag(2)
        }
        .accentColor(blue)
        .preferredColorScheme(.light)
        .onAppear {
            hasAppeared = true
            // Some iOS 15 builds deliver .onAppear while the scene is still
            // .inactive. Check again on the next main-loop turn.
            DispatchQueue.main.async { resumeIfAllowed() }
            rewards.refresh(address: address)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                DispatchQueue.main.async { resumeIfAllowed() }
                rewards.refresh(address: address)
            case .background:
                pauseForBackground()
            case .inactive:
                // Temporary interruptions (Control Center, incoming calls,
                // permission dialogs) are NOT a background transition.
                // Stopping here stranded the miner at 0 H/s on iPhone 7.
                break
            @unknown default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Additional lifecycle signal for iOS 15 / sideloaded installations.
            DispatchQueue.main.async { resumeIfAllowed() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            pauseForBackground()
        }
        .onChange(of: miner.running) { active in
            UIApplication.shared.isIdleTimerDisabled = active && UIApplication.shared.applicationState == .active
        }
        .onChange(of: miner.status) { value in
            // Do not auto-restart immediately after an overheating or memory alert.
            if value.hasPrefix("Sécurité") || value.hasPrefix("Mémoire insuffisante") {
                wantsMining = false
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private func resumeIfAllowed() {
        guard hasAppeared, wantsMining, !miner.running,
              UIApplication.shared.applicationState == .active else { return }
        miner.start(to: address)
    }

    private func pauseForBackground() {
        guard UIApplication.shared.applicationState == .background || scenePhase == .background else { return }
        if miner.running {
            miner.stop(reason: "En pause : application en arrière-plan")
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private var miningScreen: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    earningsCard
                    statusCard
                    actionButton

                    HStack(spacing: 12) {
                        metric("Puissance réelle", String(format: "%.2f", miner.rate), "H/s")
                        metric("Calculs effectués", miner.hashes.formatted(), "hashs")
                    }
                    HStack(spacing: 12) {
                        compactMetric("Parts acceptées", "\(miner.accepted)", "checkmark.circle.fill")
                        compactMetric("Parts refusées", "\(miner.rejected)", "xmark.circle")
                    }

                    Text("Un résultat peut prendre longtemps sur l'iPhone 7. 0 H/s au démarrage signifie que le calcul n'a pas encore commencé ou abouti.")
                        .font(.system(size: 12))
                        .foregroundColor(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Minage RandomX light : iPhone à garder ouvert. Arrêt automatique si la température devient excessive.")
                        .font(.system(size: 11))
                        .foregroundColor(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 17)
                .padding(.top, 17)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MINAGER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(blue)
                Text("Minage Monero")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(ink)
            }
            Spacer()
            Image(systemName: "cpu.fill")
                .font(.system(size: 20))
                .foregroundColor(blue)
                .frame(width: 44, height: 44)
                .background(card, in: RoundedRectangle(cornerRadius: 14))
            }
    }

    // Earnings are read from the pool's public wallet statistics.
    // They are NEVER estimated from local hashes or shares.
    private var earningsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Mes gains réels", systemImage: "wallet.bifold")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ink)
                Spacer()
                Button {
                    rewards.refresh(address: address)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(blue)
                }
                .disabled(rewards.updating)
                .accessibilityLabel("Actualiser mes gains")
            }
            Text(rewards.unpaidXMR.map { String(format: "%.8f XMR", $0) } ?? "Non disponible")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if let xmr = rewards.unpaidXMR, let price = rewards.priceEUR {
                Text("≈ \(String(format: "%.4f", xmr * price)) € • estimation, pas un solde en euros")
                    .font(.system(size: 13))
                    .foregroundColor(secondary)
            }
            Text("Récompenses en attente sur HashVault, pas encore envoyées à Cake Wallet.")
                .font(.system(size: 11))
                .foregroundColor(secondary)
                .fixedSize(horizontal: false, vertical: true)
            if rewards.unpaidXMR == nil {
                Text("Le pool n'a pas encore fourni de solde vérifiable pour cette adresse.")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                selectedTab = 1
            } label: {
                Label("Versement vers Cake Wallet", systemImage: "arrow.right.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .foregroundColor(blue)
            .background(background, in: RoundedRectangle(cornerRadius: 13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(card, in: RoundedRectangle(cornerRadius: 18))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Circle()
                    .fill(miner.running && miner.hashes > 0 ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(miner.running
                     ? (miner.hashes > 0 ? "Calcul RandomX actif" : "Connexion / initialisation")
                     : "Minage arrêté")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ink)
                Spacer()
                Text("XMR")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(blue)
            }
            Text(miner.status)
                .font(.system(size: 14))
                .foregroundColor(secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "network")
                Text("Pool HashVault · RandomX light")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(card, in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionButton: some View {
        Button {
            if miner.running {
                wantsMining = false
                miner.stop(reason: "Arrêt manuel")
                UIApplication.shared.isIdleTimerDisabled = false
            } else {
                // The button always allows a real retry after a failed connect
                // or unexpected pause, even if wantsMining was already true.
                wantsMining = true
                if UIApplication.shared.applicationState == .active {
                    miner.start(to: address)
                }
            }
        } label: {
            Label(miner.running ? "Arrêter le minage" : "Démarrer le minage",
                  systemImage: miner.running ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 57)
        }
        .foregroundColor(.white)
        .background(miner.running ? ink : blue, in: RoundedRectangle(cornerRadius: 17))
        .accessibilityHint("Met en pause ou reprend le calcul Monero sur cet iPhone")
    }

    private func metric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(secondary)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func compactMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .foregroundColor(blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ink)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(card, in: RoundedRectangle(cornerRadius: 15))
    }

    private var settingsScreen: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Mon portefeuille")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(ink)
                    Label("Cake Wallet · Monero XMR", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(blue)
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Adresse publique connectée")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondary)
                        Text(String(address.prefix(13)) + "…" + String(address.suffix(11)))
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(ink)
                        Button {
                            UIPasteboard.general.string = address
                        } label: {
                            Label("Copier l'adresse", systemImage: "doc.on.doc")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(card, in: RoundedRectangle(cornerRadius: 16))
                    Text("Seule l'adresse de réception est enregistrée. Tes mots de récupération restent dans Cake Wallet.")
                        .font(.system(size: 13))
                        .foregroundColor(secondary)
                    Button(role: .destructive) {
                        wantsMining = false
                        miner.stop(reason: "Compte déconnecté")
                        UIApplication.shared.isIdleTimerDisabled = false
                        onDisconnect()
                    } label: {
                        Label("Changer de portefeuille", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(card, in: RoundedRectangle(cornerRadius: 15))
                }
                .padding(18)
            }
        }
    }
}
