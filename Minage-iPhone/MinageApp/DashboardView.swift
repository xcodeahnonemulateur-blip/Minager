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
    @AppStorage("ducoUsername") private var username = ""
    @State private var miningKey = ""
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
                    orb
                    HStack(spacing: 12) {
                        metric("PUISSANCE", String(format: "%.0f", miner.hashrate), "H/s", "bolt.fill")
                        metric("PARTS ACCEPTÉES", "\(miner.accepted)", "validées", "checkmark.seal.fill")
                    }
                    HStack(spacing: 12) {
                        metric("REFUSÉES", "\(miner.rejected)", "parts", "xmark.circle.fill")
                        metric("SESSION", formattedDuration, "écoulées", "clock.fill")
                    }
                    controls
                    statusCard
                    infoCard
                    Text("Duino-Coin indépendant • Version laboratoire 0.1")
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
        .alert("Ton portefeuille DUCO", isPresented: $showHelp) {
            Button("Ouvrir le portefeuille") {
                UIApplication.shared.open(URL(string: "https://wallet.duinocoin.com/")!)
            }
            Button("Fermer", role: .cancel) {}
        } message: {
            Text("Crée un compte sur le portefeuille officiel Duino-Coin. Son identifiant est le destinataire des gains DUCO. Cake Wallet ne prend pas en charge DUCO. Ne saisis jamais une phrase de récupération ici.")
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

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Compte de minage").font(.headline)
                Spacer()
                Button(action: { showHelp = true }) {
                    Label("Aide", systemImage: "questionmark.circle")
                        .font(.system(size: 12)).foregroundColor(Palette.cyan)
                }
            }
            TextField("Identifiant DUCO (pas une adresse BTC)", text: $username)
                .textContentType(.username).textInputAutocapitalization(.never)
                .autocorrectionDisabled().padding(13)
                .background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
                .disabled(miner.isMining)
            SecureField("Clé de minage (si activée)", text: $miningKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled().padding(13)
                .background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
                .disabled(miner.isMining)
            Button {
                if miner.isMining { miner.stop() }
                else { miner.start(username: username, miningKey: miningKey) }
            } label: {
                Label(miner.isMining ? "Arrêter le minage" : "Démarrer le minage",
                      systemImage: miner.isMining ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
            }
            .foregroundColor(Palette.background)
            .background(miner.isMining ? Color.orange : Palette.cyan,
                        in: RoundedRectangle(cornerRadius: 15))
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
            Text("Ce compteur montre des calculs et des parts réellement soumises au pool, pas des euros. Le solde et les retraits sont consultables sur le portefeuille DUCO officiel.")
            Text("Le minage s'arrête en arrière-plan et si la température du système devient trop élevée. Ne laisse pas un vieil iPhone branché sans surveillance.")
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
