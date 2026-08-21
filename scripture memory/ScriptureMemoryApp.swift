//
//  ScriptureMemoryApp.swift
//  Scripture Memory
//
//  The top-level definition of the Scripture Memory app.
//

import SwiftUI

@main
struct ScriptureMemoryApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Before anything else: the stores below read their defaults on first
        // access and cache them, so progress has to be moved onto the permanent
        // card ids while nothing has loaded yet. No-op after the first launch.
        IdentityMigration.runIfNeeded()
        // Likewise before any view reads the cap: carries a deliberately-chosen
        // per-day new-card setting onto the day/week keys, so the new 2-a-week
        // default only lands on people who never picked one.
        NewCardCap.migrateIfNeeded()
    }

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
                    // Pick up any published verse corrections. Writes a cache
                    // file and nothing else — this launch keeps the catalog it
                    // started with, and the next one reads the new one. See
                    // `VerseCatalog`. No-op unless Supabase is configured.
                    await VerseCatalog.refreshIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                StreakStore.shared.recordToday()
                // Also on resume, not just on launch. `.task` above runs once per
                // cold start, and iOS keeps apps suspended for days — so relying
                // on it alone meant a published correction needed two launches to
                // appear: one to download it, another to read it. Fetching here
                // means the cache is usually already current by the time the app
                // is next started cold, leaving one restart instead of two.
                //
                // Still only writes the cache; nothing changes mid-session. See
                // `VerseCatalog`.
                Task { await VerseCatalog.refreshIfNeeded() }
            }
            // Re-arm the reminder window on backgrounding so its pre-scheduled
            // due counts reflect any reviews just completed.
            if phase == .background {
                Task { await NotificationManager.refreshFromSettings() }
            }
        }
    }
}
