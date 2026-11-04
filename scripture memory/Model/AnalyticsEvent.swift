import Foundation

/// Every usage signal the app can send. Adding one is a new case plus its line
/// in `name` and `parameters`; nothing else changes.
///
/// No verse text, search terms, reminder times or iCloud data ever goes in an
/// event. Counts and durations are sent as ranges.
enum AnalyticsEvent: Equatable {
    case screenViewed(AnalyticsScreen)
    case onboardingFinished(start: OnboardingStart, bibleVersion: String)
    case openedFromWidget(destination: WidgetDestination)

    case packOpened(pack: String, from: PackSource)
    case packClosed(how: PackCloseMethod, seconds: TimeInterval, flips: Int)
    case learntChanged(learnt: Bool, from: VerseActionSource)
    case starChanged(starred: Bool, from: VerseActionSource)
    case packsReordered
    case packVisibilityChanged(hidden: Bool)
    case ownPackCreated(from: OwnPackSource)
    case ownVerseAdded(source: OwnVerseSource)
    case ankiImported(verses: Int, withHistory: Int, matched: Int)

    case sessionStarted(StudySessionStart)
    case sessionEnded(StudySessionSummary)

    case searchPerformed(results: Int)
    case searchResultOpened(rank: Int, matchedOnReference: Bool)
    case searchFoundNothing

    case settingChanged(setting: String, value: String)

    static let ownPackLabel = "Own pack"

    func redactingPacks(_ isOwn: (String) -> Bool) -> AnalyticsEvent {
        switch self {
        case .packOpened(let pack, let from) where isOwn(pack):
            return .packOpened(pack: Self.ownPackLabel, from: from)
        case .sessionStarted(var start):
            if let pack = start.pack, isOwn(pack) { start.pack = Self.ownPackLabel }
            return .sessionStarted(start)
        default:
            return self
        }
    }

    var name: String {
        switch self {
        case .screenViewed:          return "Screen.viewed"
        case .onboardingFinished:    return "Onboarding.finished"
        case .openedFromWidget:      return "App.openedFromWidget"
        case .packOpened:            return "Pack.opened"
        case .packClosed:            return "Pack.closed"
        case .learntChanged:         return "Verse.learntChanged"
        case .starChanged:           return "Verse.starChanged"
        case .packsReordered:        return "Packs.reordered"
        case .packVisibilityChanged: return "Packs.visibilityChanged"
        case .ownPackCreated:        return "OwnPack.created"
        case .ownVerseAdded:         return "OwnPack.verseAdded"
        case .ankiImported:          return "OwnPack.ankiImported"
        case .sessionStarted(let s): return "\(s.kind.signalPrefix).started"
        case .sessionEnded(let s):   return "\(s.kind.signalPrefix).ended"
        case .searchPerformed:       return "Search.performed"
        case .searchResultOpened:    return "Search.resultOpened"
        case .searchFoundNothing:    return "Search.foundNothing"
        case .settingChanged:        return "Settings.changed"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .screenViewed(let screen):
            return ["screen": screen.rawValue]
        case .onboardingFinished(let start, let version):
            return ["start": start.rawValue, "bibleVersion": version]
        case .openedFromWidget(let destination):
            return ["destination": destination.rawValue]
        case .packOpened(let pack, let from):
            return ["pack": pack, "from": from.rawValue]
        case .packClosed(let how, let seconds, let flips):
            return ["how": how.rawValue, "timeOpen": AnalyticsRange.duration(seconds),
                    "flips": AnalyticsRange.count(flips)]
        case .learntChanged(let learnt, let from):
            return ["learnt": String(learnt), "from": from.rawValue]
        case .starChanged(let starred, let from):
            return ["starred": String(starred), "from": from.rawValue]
        case .packsReordered, .searchFoundNothing:
            return [:]
        case .packVisibilityChanged(let hidden):
            return ["hidden": String(hidden)]
        case .ownPackCreated(let from):
            return ["from": from.rawValue]
        case .ownVerseAdded(let source):
            return ["source": source.rawValue]
        case .ankiImported(let verses, let withHistory, let matched):
            return ["verses": AnalyticsRange.count(verses), "withHistory": AnalyticsRange.count(withHistory),
                    "matched": AnalyticsRange.count(matched)]
        case .sessionStarted(let s):
            return s.parameters
        case .sessionEnded(let s):
            return s.parameters
        case .searchPerformed(let results):
            return ["results": AnalyticsRange.count(results)]
        case .searchResultOpened(let rank, let onReference):
            return ["rank": AnalyticsRange.count(rank), "matchedOn": onReference ? "reference" : "text"]
        case .settingChanged(let setting, let value):
            return ["setting": setting, "value": value]
        }
    }
}

enum AnalyticsScreen: String, CaseIterable {
    case home, packs, quiz, settings, search
    case pack, dailyReview, quizSession, practice
    case streak, organizePacks, pinPicker, currentVersePicker, onboarding
}

enum OnboardingStart: String { case beginning, pickedVerse, restoredFromICloud }
enum WidgetDestination: String { case read, review }
enum PackSource: String { case shelf, search, homeCard, widget }
enum OwnPackSource: String { case newPack, ankiImport }
enum OwnVerseSource: String { case typed, pasted, bundledText }
enum PackCloseMethod: String { case edgeSwipe, closeButton }
enum VerseActionSource: String { case card, menu }

enum StudySessionKind: String {
    case review, extraRound, quiz, practice

    var signalPrefix: String {
        switch self {
        case .review:     return "Review"
        case .extraRound: return "Review.extraRound"
        case .quiz:       return "Quiz"
        case .practice:   return "Practice"
        }
    }
}

struct StudySessionStart: Equatable {
    var kind: StudySessionKind
    var cards: Int
    var studyMode: String
    var hardMode: Bool
    var newCards = 0
    var learningCards = 0
    var dueCards = 0
    var knownCards = 0
    var reviewedToday = 0
    var pack: String?

    var parameters: [String: String] {
        var p = ["cards": AnalyticsRange.count(cards), "studyMode": studyMode, "hardMode": String(hardMode)]
        if kind == .review {
            p["new"] = AnalyticsRange.count(newCards)
            p["learning"] = AnalyticsRange.count(learningCards)
            p["due"] = AnalyticsRange.count(dueCards)
            p["known"] = AnalyticsRange.count(knownCards)
            p["reviewedToday"] = AnalyticsRange.count(reviewedToday)
        }
        if let pack { p["pack"] = pack }
        return p
    }
}

struct StudySessionSummary: Equatable {
    var kind: StudySessionKind
    var finished: Bool
    var cards: Int
    var cardsDone: Int
    var seconds: TimeInterval
    var again = 0, hard = 0, good = 0, easy = 0
    var peeks = 0
    var undos = 0
    var mistakes = 0
    var usedVoice = false

    var parameters: [String: String] {
        var p = [
            "finished": String(finished),
            "cards": AnalyticsRange.count(cards),
            "cardsDone": AnalyticsRange.count(cardsDone),
            "time": AnalyticsRange.duration(seconds),
            "peeks": AnalyticsRange.count(peeks),
            "usedVoice": String(usedVoice),
        ]
        switch kind {
        case .review, .extraRound:
            p["again"] = AnalyticsRange.count(again)
            p["hard"] = AnalyticsRange.count(hard)
            p["good"] = AnalyticsRange.count(good)
            p["easy"] = AnalyticsRange.count(easy)
            p["undos"] = AnalyticsRange.count(undos)
        case .quiz, .practice:
            p["mistakes"] = AnalyticsRange.count(mistakes)
            p["allCorrect"] = String(finished && mistakes == 0)
        }
        return p
    }
}

enum AnalyticsBuild {
    static func isTest(isSimulator: Bool, receiptName: String?) -> Bool {
        isSimulator || receiptName == "sandboxReceipt"
    }
}

struct ActiveTimer: Equatable {
    private var total: TimeInterval = 0
    private var resumedAt: Date?

    init(now: Date = Date()) { resumedAt = now }

    mutating func pause(now: Date = Date()) {
        total = elapsed(now: now)
        resumedAt = nil
    }

    mutating func resume(now: Date = Date()) {
        if resumedAt == nil { resumedAt = now }
    }

    func elapsed(now: Date = Date()) -> TimeInterval {
        total + (resumedAt.map { now.timeIntervalSince($0) } ?? 0)
    }
}

enum AnalyticsRange {
    static func count(_ n: Int) -> String {
        switch n {
        case ..<1:     return "0"
        case 1:        return "1"
        case 2...5:    return "2-5"
        case 6...10:   return "6-10"
        case 11...20:  return "11-20"
        case 21...50:  return "21-50"
        default:       return "50+"
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<30:    return "<30s"
        case ..<60:    return "30s-1m"
        case ..<180:   return "1-3m"
        case ..<600:   return "3-10m"
        case ..<1800:  return "10-30m"
        default:       return "30m+"
        }
    }
}
