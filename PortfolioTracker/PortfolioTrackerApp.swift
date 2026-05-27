import SwiftUI

@main
struct PortfolioTrackerApp: App {
    @StateObject private var api = APIClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .preferredColorScheme(.dark)
        }
    }
}
