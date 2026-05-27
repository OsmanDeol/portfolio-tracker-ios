import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PortfolioView()
                .tabItem { Label("Portfolio", systemImage: "chart.pie.fill") }

            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "star.fill") }

            AnalystView()
                .tabItem { Label("AI Analyst", systemImage: "sparkles") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(.appAccent)
    }
}

#Preview {
    ContentView()
        .environmentObject(APIClient())
}
