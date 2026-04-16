import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                PackListView()
            }
            .tabItem {
                Image(systemName: "rectangle.stack.fill")
                Text("Packs")
            }

            NavigationStack {
                SRSDashboardView()
            }
            .tabItem {
                Image(systemName: "calendar.badge.checkmark")
                Text("Daily")
            }

            NavigationStack {
                TestSetupView()
            }
            .tabItem {
                Image(systemName: "checkmark.circle.fill")
                Text("Review")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
        }
    }
}
