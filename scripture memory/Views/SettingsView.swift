import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("studyMode")          private var studyMode:    StudyMode    = .firstLetter
    @AppStorage("bibleVersion")       private var bibleVersion: BibleVersion = .niv84
    @AppStorage("hardMode")           private var hardMode:     Bool         = false
    @AppStorage("srs.dailyNewCap")    private var dailyNewCap:    Int        = 1
    @AppStorage("srs.dailyReviewCap") private var dailyReviewCap: Int        = 5

    @AppStorage(NotificationManager.Keys.enabled) private var reminderEnabled = false
    @AppStorage(NotificationManager.Keys.hour)    private var reminderHour    = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.minute)  private var reminderMinute  = NotificationManager.defaultMinute

    @State private var showResetSRSAlert      = false
    @State private var showNotifDeniedAlert   = false
    @State private var showLearningSetup      = false
    @State private var showResetLearningAlert = false

    @ObservedObject private var learning  = LearningStore.shared
    @ObservedObject private var packPrefs = PackPreferencesStore.shared

    @Environment(\.openURL) private var openURL

    private var learningOrdered: [Verse] { packPrefs.visible(from: bibleVersion.packs).flatMap(\.verses) }

    /// Book + reference of the verse the user is currently on, for the Settings row.
    private var currentLearningLabel: String {
        let ordered = learningOrdered
        guard !ordered.isEmpty else { return "—" }
        guard let cur = learning.current(in: ordered) else { return "All learnt 🎉" }
        return "\(cur.verse.book) \(cur.verse.reference)"
    }

    var body: some View {
        List {
            // ── Most-changed: how you study ──────────────────────────────
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
                Toggle(isOn: $hardMode) {
                    Label("Hard Mode", systemImage: "eye.slash")
                }
            } footer: {
                Text("Hides all hints — no word placeholders shown during review.")
            }

            // ── Daily pace ───────────────────────────────────────────────
            Section {
                capRow(icon: "sparkles", title: "New cards / day",
                       binding: $dailyNewCap, range: 0...50)
                capRow(icon: "arrow.clockwise", title: "Reviews / day",
                       binding: $dailyReviewCap, range: 0...500, step: 5)
            } header: {
                Text("Daily Review")
            } footer: {
                Text("New-card cap is shared across all active packs.")
            }

            Section {
                Toggle(isOn: $reminderEnabled) {
                    Label("Daily Reminder", systemImage: "bell.badge")
                }
                if reminderEnabled {
                    DatePicker("Remind me at",
                               selection: reminderTime,
                               displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminders")
            }
            .onChange(of: reminderEnabled) { _, on in handleReminderToggle(on) }
            .onChange(of: reminderHour)    { _, _ in Task { await NotificationManager.refreshFromSettings() } }
            .onChange(of: reminderMinute)  { _, _ in Task { await NotificationManager.refreshFromSettings() } }
            .alert("Notifications are off", isPresented: $showNotifDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Turn on notifications for Scripture Memory in the iOS Settings app to receive daily reminders.")
            }

            // ── Set-once content & progress ──────────────────────────────
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
                Button {
                    showLearningSetup = true
                } label: {
                    HStack(spacing: 8) {
                        Label("Starting point", systemImage: "flag.checkered")
                        Spacer()
                        Text(currentLearningLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button(role: .destructive) {
                    showResetLearningAlert = true
                } label: {
                    Text("Reset learning progress")
                }
            } header: {
                Text("Learning")
            } footer: {
                Text("Sets the verse shown on your Home screen. Everything before your starting point counts as already learnt.")
            }
            .sheet(isPresented: $showLearningSetup) {
                LearningSetupView()
            }
            .alert("Reset learning progress?", isPresented: $showResetLearningAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    LearningStore.shared.resetProgress()
                }
            } message: {
                Text("Your current verse returns to the very first verse. Verses you've marked learnt will be forgotten.")
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
                LabeledContent("Version", value: appVersionString)
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
    }

    /// A "icon + title … value [− +]" row. The icon sits in a fixed-width column
    /// so the two rows' titles align and the icon stays vertically centred with
    /// the title (the old Stepper-wrapped Label floated the icon above the text).
    private func capRow(icon: String, title: String,
                        binding: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        HStack(spacing: 0) {
            // Real Label so the icon matches the other rows' tint; fixed-width
            // icon column so the two titles line up.
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).frame(width: 24, alignment: .center)
            }
            Spacer(minLength: 8)
            Text("\(binding.wrappedValue)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.trailing, 6)
            Stepper(title, value: binding, in: range, step: step)
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
