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
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
        }
    }
}
