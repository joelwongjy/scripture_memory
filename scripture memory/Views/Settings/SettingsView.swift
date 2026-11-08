import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage(StudyMode.storageKey)          private var studyMode:    StudyMode    = .firstLetter
    @AppStorage(BibleVersion.storageKey)       private var bibleVersion: BibleVersion = .niv84
    @AppStorage("hardMode")           private var hardMode:     Bool         = false
    @AppStorage(NewCardCap.amountKey) private var newCapAmount:  Int        = NewCardCap.fallback.amount
    @AppStorage(NewCardCap.unitKey)   private var newCapUnit:    NewCapUnit = NewCardCap.fallback.unit
    @AppStorage(NewCardCap.dailyReviewCapKey) private var dailyReviewCap: Int = NewCardCap.dailyReviewCapDefault
    @AppStorage(SRSQueueBuilder.NewCardPolicy.reviewsKnownKey)
    private var reviewsKnownVerses = SRSQueueBuilder.NewCardPolicy.reviewsKnownDefault
    @AppStorage(CardAppearance.storageKey)     private var cardAppearance: CardAppearance = .alwaysLight

    @AppStorage(NotificationManager.Keys.enabled) private var reminderEnabled = false
    @AppStorage(NotificationManager.Keys.hour)    private var reminderHour    = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.minute)  private var reminderMinute  = NotificationManager.defaultMinute

    @AppStorage(Analytics.shareUsageKey) private var shareUsage = Analytics.shareUsageDefault

    @State private var showResetSRSAlert      = false
    @State private var exportedFile: ExportedFile?
    @State private var nothingToExport        = false
    @State private var showNotifDeniedAlert   = false
    @State private var showLearningSetup      = false
    @State private var settlingLogs: [String: Task<Void, Never>] = [:]

    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared

    @Environment(\.openURL) private var openURL

    private var learningOrdered: [Verse] { Catalogue.verses(in: packPrefs.visible(from: bibleVersion.packs)) }

    /// Book + reference of the verse the user is currently on, for the Settings row.
    private var currentLearningLabel: String {
        let ordered = learningOrdered
        guard !ordered.isEmpty else { return "None" }
        guard let cur = learning.current(in: ordered) else { return "All learnt" }
        return "\(cur.verse.book) \(cur.verse.reference)"
    }

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
                Toggle("Hard Mode", isOn: $hardMode)
            } header: {
                Text("Study")
            } footer: {
                Text(hardMode ? "\(studyMode.instructions) Hard Mode hides the word blanks." : studyMode.instructions)
            }

            Section {
                Button {
                    showLearningSetup = true
                } label: {
                    HStack(spacing: 8) {
                        rowLabel("Current Verse", "bookmark.fill")
                            // The title is two words; the reference is the one
                            // that should give way, not wrap the title mid-phrase.
                            .lineLimit(1)
                            .layoutPriority(1)
                        Spacer()
                        Text(currentLearningLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        RowChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text("Learning")
            } footer: {
                Text("Verses before your current verse count as learnt.")
            }

            Section {
                capRow(icon: "sparkles", title: newCapUnit.settingTitle,
                       binding: $newCapAmount, range: 0...50)
                // The period the cap above is counted over. Two a week is the
                // pace the printed programmes set; a per-day cap of 1 quietly
                // permits seven a week, which is how the queue becomes a backlog.
                Picker(selection: $newCapUnit) {
                    ForEach(NewCapUnit.allCases, id: \.self) { unit in
                        Text(unit.pickerLabel).tag(unit)
                    }
                } label: {
                    rowLabel("Count Per", "calendar")
                }
                .pickerStyle(.segmented)
                capRow(icon: "arrow.clockwise", title: "Reviews per Day",
                       binding: $dailyReviewCap, range: 0...500)
                Toggle(isOn: $reviewsKnownVerses) {
                    rowLabel("Review Earlier Verses", "checkmark.circle")
                }
            } header: {
                Text("Daily Review")
            } footer: {
                Text("Review Earlier Verses brings verses before your starting point into review, a few at a time. Limits apply across all packs.")
            }

            Section {
                Toggle(isOn: $reminderEnabled) {
                    rowLabel("Daily Reminder", "bell.badge")
                }
                if reminderEnabled {
                    DatePicker("Time",
                               selection: reminderTime,
                               displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Only on days with verses due.")
            }
            .onChange(of: reminderEnabled) { _, on in handleReminderToggle(on) }
            .onChange(of: reminderHour)    { _, _ in Task { await NotificationManager.refreshFromSettings() } }
            .onChange(of: reminderMinute)  { _, _ in Task { await NotificationManager.refreshFromSettings() } }
            .alert("Notifications Are Off", isPresented: $showNotifDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Turn on notifications for Scripture Memory in Settings.")
            }

            Section {
                Picker(selection: $cardAppearance) {
                    ForEach(CardAppearance.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                } label: {
                    rowLabel("Cards", "rectangle.on.rectangle")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Display")
            } footer: {
                Text("Match Appearance uses dark cards in Dark Mode.")
            }

            Section {
                Button(action: exportToAnki) {
                    rowLabel("Export to Anki", "square.and.arrow.up")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Saves your own packs and every pack you’ve started, with review history, as an Anki deck. Open it in Anki, or import it into Scripture Memory on another phone.")
            }

            Section {
                Toggle(isOn: $shareUsage) {
                    rowLabel("Share Anonymous Usage", "chart.bar")
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Sends which screens and features you use, never your verses or personal details.")
            }
            .onChange(of: shareUsage) { _, on in Analytics.setEnabled(on) }

            Section {
                Button(role: .destructive) {
                    showResetSRSAlert = true
                } label: {
                    Text("Reset Review Progress")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } footer: {
                Text("Clears all review scheduling. This can't be undone.")
            }
            .alert("Reset Review Progress?", isPresented: $showResetSRSAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    SRSStore.shared.resetAll()
                }
            } message: {
                Text("Every card's review schedule will be cleared.")
            }

            Section {
                LabeledContent("Version", value: appVersionString)
                NavigationLink {
                    AcknowledgmentsView()
                } label: {
                    Text("Acknowledgments")
                }
            } header: {
                Text("About")
            } footer: {
                Text("Made with God's ❤️ for The Navigators")
                    .font(.system(.subheadline, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
            }
        }
        .navigationTitle("Settings")
        .analyticsScreen(.settings)
        .onChange(of: studyMode)          { _, v in logSetting("studyMode", v.rawValue) }
        .onChange(of: hardMode)           { _, v in logSetting("hardMode", String(v)) }
        .onChange(of: newCapAmount)       { _, v in logSettingOnceSettled("newCards", String(v)) }
        .onChange(of: newCapUnit)         { _, v in logSetting("newCardsPer", v.rawValue) }
        .onChange(of: dailyReviewCap)     { _, v in logSettingOnceSettled("reviewsPerDay", String(v)) }
        .onChange(of: reviewsKnownVerses) { _, v in logSetting("reviewEarlierVerses", String(v)) }
        .onChange(of: cardAppearance)     { _, v in logSetting("cardAppearance", v.rawValue) }
        .onChange(of: reminderEnabled)    { _, v in logSetting("dailyReminder", String(v)) }
        // Hosted on the List (not the Learning Section) so the first presentation
        // doesn't self-dismiss — a sheet anchored to a lazy List section can tear
        // down on its initial layout pass.
        .sheet(isPresented: $showLearningSetup) {
            LearningSetupView()
        }
        .sheet(item: $exportedFile) { file in
            ActivityView(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .alert("Nothing to Export Yet", isPresented: $nothingToExport) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Start a pack or make your own, and it will be included.")
        }
    }

    private func exportToAnki() {
        do {
            if let url = try AnkiExporter.exportFile(for: bibleVersion) {
                exportedFile = ExportedFile(url: url)
            } else {
                nothingToExport = true
            }
        } catch {
            nothingToExport = true
        }
    }

    private func logSetting(_ setting: String, _ value: String) {
        Analytics.log(.settingChanged(setting: setting, value: value))
    }

    private func logSettingOnceSettled(_ setting: String, _ value: String) {
        settlingLogs[setting]?.cancel()
        settlingLogs[setting] = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            logSetting(setting, value)
        }
    }

    /// A settings-row label with the SF Symbol pinned to a uniform 24pt column,
    /// so every row's glyph aligns and every title shares one inset. Keeps the
    /// system `Label` layout, so spacing and the accent tint match iOS defaults.
    private func rowLabel(_ title: String, _ systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).frame(width: 24, alignment: .center)
        }
    }

    /// A "icon + title … value [− +]" row. The icon column (via `rowLabel`) keeps
    /// the two titles aligned and the icon vertically centred with the title.
    private func capRow(icon: String, title: String,
                        binding: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 0) {
            rowLabel(title, icon)
            Spacer(minLength: 8)
            Text("\(binding.wrappedValue)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.trailing, 6)
            Stepper(title, value: binding, in: range)
                .labelsHidden()
        }
    }

    /// Two-way bridge between the persisted hour/minute and the DatePicker's Date.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour   = c.hour   ?? NotificationManager.defaultHour
                reminderMinute = c.minute ?? NotificationManager.defaultMinute
            }
        )
    }

    /// On enable: ask permission, then schedule (or revert + explain if denied).
    /// On disable: cancel the pending reminder.
    private func handleReminderToggle(_ on: Bool) {
        if on {
            Task {
                let granted = await NotificationManager.requestAuthorization()
                if granted {
                    await NotificationManager.refreshFromSettings()
                } else {
                    reminderEnabled = false
                    showNotifDeniedAlert = true
                }
            }
        } else {
            NotificationManager.cancelDailyReminder()
        }
    }

    /// App marketing version (+ build) read from the bundle so it always tracks
    /// the shipped build instead of a hardcoded string.
    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = info?["CFBundleVersion"] as? String
        if let build, !build.isEmpty, build != version {
            return "\(version) (\(build))"
        }
        return version
    }
}

#Preview {
    NavigationStack { SettingsView() }
}

private struct ExportedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
