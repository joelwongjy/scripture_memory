import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("studyMode")          private var studyMode:    StudyMode    = .firstLetter
    @AppStorage("bibleVersion")       private var bibleVersion: BibleVersion = .niv84
    @AppStorage("hardMode")           private var hardMode:     Bool         = false
    @AppStorage("srs.dailyNewCap")    private var dailyNewCap:    Int        = 1
    @AppStorage("srs.dailyReviewCap") private var dailyReviewCap: Int        = 5
    @AppStorage("homeVerseStartMode.v1") private var homeVerseStartMode: HomeVerseStartMode = .read

    @AppStorage(NotificationManager.Keys.enabled) private var reminderEnabled = false
    @AppStorage(NotificationManager.Keys.hour)    private var reminderHour    = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.minute)  private var reminderMinute  = NotificationManager.defaultMinute

    @State private var showResetSRSAlert      = false
    @State private var showNotifDeniedAlert   = false
    @State private var showLearningSetup      = false

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
                    rowLabel("Hard Mode", "eye.slash")
                }
            } footer: {
                Text("Hides all hints — no word placeholders shown during review.")
            }

            // ── Daily pace ───────────────────────────────────────────────
            Section {
                capRow(icon: "sparkles", title: "New cards / day",
                       binding: $dailyNewCap, range: 0...50)
                capRow(icon: "arrow.clockwise", title: "Reviews / day",
                       binding: $dailyReviewCap, range: 0...500)
            } header: {
                Text("Daily Review")
            } footer: {
                Text("New-card cap is shared across all active packs.")
            }

            Section {
                Toggle(isOn: $reminderEnabled) {
                    rowLabel("Daily Reminder", "bell.badge")
                }
                if reminderEnabled {
                    DatePicker("Remind me at",
                               selection: reminderTime,
                               displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Sent at this time on days you have verses due.")
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
                        rowLabel("Current verse", "bookmark.fill")
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

                Picker(selection: $homeVerseStartMode) {
                    ForEach(HomeVerseStartMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                } label: {
                    rowLabel("Opens in", "book")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Learning")
            } footer: {
                Text("Your current verse shows on Home; everything before it counts as learnt. Choose whether tapping it opens to read or review.")
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
        // Hosted on the List (not the Learning Section) so the first presentation
        // doesn't self-dismiss — a sheet anchored to a lazy List section can tear
        // down on its initial layout pass.
        .sheet(isPresented: $showLearningSetup) {
            LearningSetupView()
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
                        binding: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        HStack(spacing: 0) {
            rowLabel(title, icon)
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

/// Dedicated screen for the scripture + content attributions, linked from
/// Settings → About. Keeps the required NIV copyright notice and the Topical
/// Memory System credit out of the main Settings footer (and makes them easy to
/// find).
struct AcknowledgmentsView: View {
    var body: some View {
        List {
            Section("Scripture") {
                Text("Scripture quotations taken from The Holy Bible, New International Version® NIV®. Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.")
            }
            Section("Topical Memory System") {
                Text("Verse selections are based on The Navigators' Topical Memory System®. This app is independent and is not affiliated with, endorsed by, or sponsored by The Navigators.")
            }
        }
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Acknowledgments") {
    NavigationStack { AcknowledgmentsView() }
}
