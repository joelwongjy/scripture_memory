//
//  App.swift
//  Scripture Memory
//
//  The top-level definition of the Scripture Memory app.
//

import SwiftUI

@main
struct ScriptureMemoryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Re-arm the daily reminder from saved settings on every
                    // launch (the OS keeps the repeating trigger, but this keeps
                    // it in sync if permission or the time changed out of band).
                    await NotificationManager.refreshFromSettings()
                }
        }
    }
}
