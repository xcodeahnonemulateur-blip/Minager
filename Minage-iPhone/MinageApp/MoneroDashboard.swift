import SwiftUI
import UIKit

private enum MiningTheme {
    static let bg = Color(red: 0.035, green: 0.052, blue: 0.115)
    static let panel = Color(red: 0.09, green: 0.12, blue: 0.22)
    static let aqua = Color(red: 0.24, green: 0.88, blue: 0.94)
    static let subtle = Color(red: 0.61, green: 0.66, blue: 0.78)
}

struct MoneroDashboard: View {
    let address: String
    let onDisconnect: () -> Void
    @StateObject private var miner = MoneroMineEngine()
    @State private var selectedTab = 0
    @State private var startedOnce = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MiningTheme.bg.ignoresSafeArea()
            TabView(selection: $selectedTab) {
                miningTab
                    .tabItem { Label("Minage", systemImage: "cpu.fill") }
                    .tag(0)
                TransferPanel(address: address)
                    .tabItem { Label("Transfert", systemImage: "arrow.left.arrow.right") }
                    .tag(1)
                settingsTab
                    .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
                    .tag(2)
            }
            .tint(MiningTheme.aqua)
        }
        .onAppear {
            if !startedOnce {
                startedOnce = true
                // The user explicitly requested mining immediately after QR association.
                miner.start(to: address)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                miner.stop(reason: "Minage suspendu : application en arrière-plan")
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onChange(of: miner.running) { now in
            UIApplication.shared.isIdleTimerDisabled = now
        }
        .onDisappear {
            miner.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var miningTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MINAGER").font(.system(size: 11, weight: .bold))
                            .tracking(3).foregroundColor(MiningTheme.aqua)
                        Text("Ton iPhone mine")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 26)).foregroundColor(MiningTheme.aqua)
                }
                ZStack {
                    Circle().stroke(MiningTheme.aqua.opacity(0.16), lineWidth: 1)
                        .frame(width: 211, height: 211)
                    Circle().fill(MiningTheme.aqua.opacity(miner.running ? 0.17 : 0.05))
                        .frame(width: 154, height: 154).blur(radius: 18)
                    Image(systemName: miner.running ? "bolt.horizontal.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 78, weight: .ultraLight))
                        .foregroundColor(MiningTheme.aqua)
                    VStack {
                        Spacer()
                        Text(miner.running ? "MINAGE EXPÉRIMENTAL" : "MINAGE ARRÊTÉ")
                            .font(.system(size: 10, weight: .bold)).tracking(2)
                            .foregroundColor(MiningTheme.aqua)
                    }
                    .frame(height: 246)
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 12) {
                    metric("PUISSANCE", String(format: "%.2f", miner.rate), "H/s")
                    metric("PARTS VALIDÉES", "\(miner.accepted)", "pool")
                }
                HStack(spacing: 12) {
                    metric("CALCULS", miner.hashes.formatted(), "RandomX light")
                    metric("REFUSÉES", "\(miner.rejected)", "parts")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("État du mineur", systemImage: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(MiningTheme.aqua)
                    Text(miner.status)
                        .font(.system(size: 13)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(MiningTheme.panel, in: RoundedRectangle(cornerRadius: 17))
                Button {
                    if miner.running { miner.stop() }
                    else { miner.start(to: address) }
                } label: {
                    Label(miner.running ? "Arrêter le minage" : "Reprendre le minage",
                          systemImage: miner.running ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .foregroundColor(MiningTheme.bg)
                .background(miner.running ? Color.orange : MiningTheme.aqua,
                            in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 7) {
                    Text("RandomX light · 256 Mo · 1 tâche CPU")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Le minage ne garantit pas de gains. Un iPhone 7 est trop lent pour atteindre rapidement un seuil de paiement. Arrêt thermique et arrêt en arrière-plan activés.")
                        .font(.system(size: 12))
                        .foregroundColor(MiningTheme.subtle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .padding(.bottom, 25)
        }
    }

    private func metric(_ title: String, _ amount: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 10, weight: .bold))
                .foregroundColor(MiningTheme.subtle)
            Text(amount).font(.system(size: 25, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.5)
                .monospacedDigit()
            Text(unit).font(.system(size: 11)).foregroundColor(MiningTheme.subtle)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MiningTheme.panel, in: RoundedRectangle(cornerRadius: 19))
    }

    private var settingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Réglages").font(.system(size: 30, weight: .bold, design: .rounded))
                Label("Monero XMR • Cake Wallet", systemImage: "wallet.bifold.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(MiningTheme.aqua)
                Text(address)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MiningTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                Text("Ceci est seulement ton adresse publique de réception. Le portefeuille Cake Wallet garde tes clés privées.")
                    .font(.system(size: 12)).foregroundColor(MiningTheme.subtle)
                Button("Changer de portefeuille", role: .destructive) {
                    miner.stop()
                    onDisconnect()
                }
                .padding(.vertical, 10)
                Spacer(minLength: 30)
            }
            .padding(22)
        }
    }
}
