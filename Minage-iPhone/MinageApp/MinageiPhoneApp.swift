import SwiftUI

@main
struct MinageiPhoneApp: App {
    @StateObject private var wallet = WalletConnection()

    var body: some Scene {
        WindowGroup {
            Group {
                if let credentials = wallet.account {
                    DashboardView(account: credentials) {
                        wallet.disconnect()
                    }
                } else {
                    WalletSetupView { currency, username, miningKey in
                        wallet.connect(currency: currency, username: username, miningKey: miningKey)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
