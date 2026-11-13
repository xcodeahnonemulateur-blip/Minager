import SwiftUI
import UIKit

@main
struct MinageiPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(.dark)
        }
    }
}
