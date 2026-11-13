import SwiftUI

@main
struct MinageiPhoneApp: App {
    @StateObject private var wallet = WalletConnection()

    var body: some Scene {
        WindowGroup {
            Group {
                if let credentials = wallet.account {
                    if credentials.currency == .monero {
                        MoneroDashboard(address: credentials.username) {
                            wallet.disconnect()
                        }
                    } else {
                        // Preserve earlier users' Duino-Coin profile and UI.
                        DashboardView(account: credentials) {
                            wallet.disconnect()
                        }
                    }
                } else {
                    WalletSetupView { currency, username, key in
                        wallet.connect(currency: currency, username: username, miningKey: key)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
