import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Control Deck
            ControlDeckView()
                .tag(0)

            // Actions List
            ActionsListView()
                .tag(1)

            // Quick Prompts
            QuickPromptsView()
                .tag(2)

            // Settings
            SettingsView()
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionManager())
}
