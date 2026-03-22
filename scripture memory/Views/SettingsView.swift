import SwiftUI

struct SettingsView: View {
    @AppStorage("studyMode")    private var studyMode:    StudyMode    = .firstLetter
    @AppStorage("bibleVersion") private var bibleVersion: BibleVersion = .niv84
    @AppStorage("hardMode")     private var hardMode:     Bool         = false

    var body: some View {
        List {
            Section {
                Picker("Study Mode", selection: $studyMode) {
                    ForEach(StudyMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Study Mode")
            } footer: {
                Text(studyMode.instructions)
            }

            Section {
                Picker("Bible Version", selection: $bibleVersion) {
                    ForEach(BibleVersion.allCases, id: \.self) { version in
                        Text(version.displayName).tag(version)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Bible Version")
            }

            Section {
                Toggle(isOn: $hardMode) {
                    Label("Hard Mode", systemImage: "eye.slash")
                }
            } footer: {
                Text("Hides all hints — no word placeholders shown during review.")
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0").foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Made with God's ❤️ for The Navigators")
                    .font(.system(size: 14, design: .serif))
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
