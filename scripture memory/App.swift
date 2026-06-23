//
//  App.swift
//  Scripture Memory
//
//  The top-level definition of the Scripture Memory app.
//

import SwiftUI

@main
struct ScriptureMemoryApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Opening the app counts toward today's streak — just viewing the
                    // verse on Home keeps it alive (the scenePhase handler below covers
                    // returning from the background later the same day).
                    StreakStore.shared.recordToday()
                    // Re-arm the daily reminder from saved settings on every
                    // launch (the OS keeps the repeating trigger, but this keeps
                    // it in sync if permission or the time changed out of band).
                    await NotificationManager.refreshFromSettings()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { StreakStore.shared.recordToday() }
        }
    }
}
