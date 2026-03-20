import SwiftUI

struct SettingsView: View {
    @AppStorage("hardMode") private var hardMode = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $hardMode) {
                    Label("Hard Mode", systemImage: "eye.slash")
                }
            } footer: {
                Text("Hides all hints - no underscores or word counts shown during review.")
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
