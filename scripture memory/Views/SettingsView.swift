import SwiftUI

struct SettingsView: View {
    @AppStorage("hardMode") private var hardMode = false
    @AppStorage("bibleVersion") private var bibleVersion = "NIV84"
    @AppStorage("studyMode") private var studyMode = "firstLetter"

    var body: some View {
        List {
            Section {
                Picker("Study Mode", selection: $studyMode) {
                    Text("First Letter").tag("firstLetter")
                    Text("Full Word").tag("fullWord")
                    Text("Submit").tag("submit")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Study Mode")
            } footer: {
                switch studyMode {
                case "firstLetter":
                    Text("Type the first letter of each word to reveal it.")
                case "fullWord":
                    Text("Type each word in full. Case and punctuation are ignored.")
                default:
                    Text("Type the full verse on the card, then tap Submit to check all at once.")
                }
            }

            Section {
                Picker("Bible Version", selection: $bibleVersion) {
                    Text("NIV 1984").tag("NIV84")
                    Text("NIV 2011").tag("NIV11")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Bible Version")
            } footer: {
                if bibleVersion == "NIV84" {
                    Text("Includes 5 Assurances and TMS 60.")
                } else {
                    Text("Includes TMS Packs A–E, 5 Assurances, and DEP 242 packs.")
                }
            }

            Section {
                Toggle(isOn: $hardMode) {
                    Label("Hard Mode", systemImage: "eye.slash")
                }
            } footer: {
                Text("Hides all hints — no underscores or word counts shown during review.")
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
