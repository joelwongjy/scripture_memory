import SwiftUI

struct SettingsView: View {
    @AppStorage("studyMode")          private var studyMode:    StudyMode    = .firstLetter
    @AppStorage("bibleVersion")       private var bibleVersion: BibleVersion = .niv84
    @AppStorage("hardMode")           private var hardMode:     Bool         = false
    @AppStorage("srs.dailyNewCap")    private var dailyNewCap:    Int        = 5
    @AppStorage("srs.dailyReviewCap") private var dailyReviewCap: Int        = 50

    @State private var showResetSRSAlert = false

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
                Stepper(value: $dailyNewCap, in: 0...50) {
                    LabeledContent("New cards / day", value: "\(dailyNewCap)")
                }
                Stepper(value: $dailyReviewCap, in: 0...500, step: 5) {
                    LabeledContent("Reviews / day", value: "\(dailyReviewCap)")
                }
            } header: {
                Text("Daily Review")
            } footer: {
                Text("New-card cap is shared across all active packs.")
            }

            Section {
                Button(role: .destructive) {
                    showResetSRSAlert = true
                } label: {
                    Text("Reset Review Progress")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } footer: {
                Text("Clears all card scheduling. Cannot be undone.")
            }
            .alert("Reset review progress?", isPresented: $showResetSRSAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    SRSStore.shared.resetAll()
                }
            } message: {
                Text("All intervals and ease values will be cleared.")
            }

            Section {
                LabeledContent("Version", value: "1.0")
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
