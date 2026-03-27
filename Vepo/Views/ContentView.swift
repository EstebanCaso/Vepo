import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .summary

    enum Tab: String, CaseIterable {
        case summary
        case log
        case connection
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionSummaryView()
                .tabItem {
                    Label("Summary", systemImage: "drop.fill")
                }
                .tag(Tab.summary)

            EventLogView()
                .tabItem {
                    Label("Log", systemImage: "list.bullet")
                }
                .tag(Tab.log)

            ConnectionStatusView()
                .tabItem {
                    Label("Bottle", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(Tab.connection)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(VepoTheme.Colors.accent)
    }
}

#Preview {
    ContentView()
}
