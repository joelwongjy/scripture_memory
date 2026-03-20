import SwiftUI

struct SettingsView: View {
    @AppStorage("hardMode") private var hardMode = false
    @AppStorage("bibleVersion") private var bibleVersion = "NIV84"
    @AppStorage("typingMode") private var typingMode = "firstLetter"
    @AppStorage("checkMode") private var checkMode = "immediate"

    var body: some View {
        List {
            Section {
                Picker("Bible Version", selection: $bibleVersion) {
                    Text("NIV 1984").tag("NIV84")
                    Text("NIV 2011").tag("NIV11")
                }
            } header: {
                Text("Bible Version")
            } footer: {
                Text("NIV 1984 includes 5 Assurances and TMS 60. NIV 2011 includes TMS Packs A–E, 5 Assurances, and DEP 242 packs.")
            }

            Section {
                Picker("Typing Mode", selection: $typingMode) {
                    Text("First Letter").tag("firstLetter")
                    Text("Full Word").tag("fullWord")
                }
            } header: {
                Text("Typing Mode")
            } footer: {
                if typingMode == "firstLetter" {
                    Text("Type the first letter of each word to reveal it.")
                } else {
                    Text("Type each word in full. Case and punctuation are ignored.")
                }
            }

            Section {
                Picker("Check Mode", selection: $checkMode) {
                    Text("Immediate").tag("immediate")
                    Text("Submit").tag("submit")
                }
            } header: {
                Text("Check Mode")
            } footer: {
                if checkMode == "immediate" {
                    Text("Each word is checked as you type it.")
                } else {
                    Text("Type the full verse, then tap Submit to check all at once.")
                }
            }

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
