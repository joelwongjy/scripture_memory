import Foundation
import os
import TelemetryDeck

@MainActor
protocol AnalyticsSink {
    func start()
    func stop()
    func send(_ event: AnalyticsEvent)
}

/// The one place events leave from. Nothing is sent once the user turns off
/// Share Anonymous Usage, which lives on this device only.
@MainActor
enum Analytics {
    static let shareUsageKey = "analytics.shareUsage"

    static var sinks: [AnalyticsSink] = {
        var sinks: [AnalyticsSink] = [TelemetryDeckSink()]
        #if DEBUG
        sinks.append(ConsoleSink())
        #endif
        return sinks
    }()

    private static var started = false

    static let shareUsageDefault = true

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: shareUsageKey) as? Bool ?? shareUsageDefault
    }

    static func start() {
        guard isEnabled, !started else { return }
        started = true
        sinks.forEach { $0.start() }
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: shareUsageKey)
        if enabled {
            start()
        } else if started {
            started = false
            sinks.forEach { $0.stop() }
        }
    }

    static func log(_ event: AnalyticsEvent) {
        guard started else { return }
        sinks.forEach { $0.send(event) }
    }
}

struct TelemetryDeckSink: AnalyticsSink {
    func start() {
        TelemetryDeck.initialize(config: .init(appID: "0215C34A-0573-47A2-861A-A405B0F98961",
                                               namespace: "com.joelwong"))
    }

    func stop() { TelemetryDeck.terminate() }

    func send(_ event: AnalyticsEvent) {
        if case .screenViewed(let screen) = event {
            TelemetryDeck.navigationPathChanged(to: screen.rawValue)
        } else {
            TelemetryDeck.signal(event.name, parameters: event.parameters)
        }
    }
}

struct ConsoleSink: AnalyticsSink {
    private let logger = Logger(subsystem: "joel.scripture-memory", category: "analytics")

    func start() { logger.debug("analytics on") }
    func stop() { logger.debug("analytics off") }

    func send(_ event: AnalyticsEvent) {
        let params = event.parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        logger.debug("\(event.name, privacy: .public) \(params.joined(separator: " "), privacy: .public)")
    }
}
