import XCTest
@testable import SRSCore

final class AnalyticsEventTests: XCTestCase {

    func testClosingAPackSaysHowManyCardsWereFlipped() {
        let event = AnalyticsEvent.packClosed(how: .closeButton, seconds: 12, flips: 3)
        XCTAssertEqual(event.parameters["flips"], "2-5")
        XCTAssertEqual(AnalyticsEvent.packClosed(how: .closeButton, seconds: 12, flips: 0).parameters["flips"], "0")
    }

    func testCountsAreSentAsRanges() {
        XCTAssertEqual(AnalyticsRange.count(0), "0")
        XCTAssertEqual(AnalyticsRange.count(1), "1")
        XCTAssertEqual(AnalyticsRange.count(5), "2-5")
        XCTAssertEqual(AnalyticsRange.count(6), "6-10")
        XCTAssertEqual(AnalyticsRange.count(20), "11-20")
        XCTAssertEqual(AnalyticsRange.count(50), "21-50")
        XCTAssertEqual(AnalyticsRange.count(51), "50+")
    }

    func testDurationsAreSentAsRanges() {
        XCTAssertEqual(AnalyticsRange.duration(12), "<30s")
        XCTAssertEqual(AnalyticsRange.duration(45), "30s-1m")
        XCTAssertEqual(AnalyticsRange.duration(120), "1-3m")
        XCTAssertEqual(AnalyticsRange.duration(400), "3-10m")
        XCTAssertEqual(AnalyticsRange.duration(900), "10-30m")
        XCTAssertEqual(AnalyticsRange.duration(4000), "30m+")
    }

    func testSessionNamesFollowTheKind() {
        let start = StudySessionStart(kind: .review, cards: 8, studyMode: "firstLetter", hardMode: false)
        XCTAssertEqual(AnalyticsEvent.sessionStarted(start).name, "Review.started")
        var extra = start
        extra.kind = .extraRound
        XCTAssertEqual(AnalyticsEvent.sessionStarted(extra).name, "Review.extraRound.started")
        let end = StudySessionSummary(kind: .quiz, finished: true, cards: 3, cardsDone: 3, seconds: 70)
        XCTAssertEqual(AnalyticsEvent.sessionEnded(end).name, "Quiz.ended")
    }

    func testReviewStartCarriesQueueMixOnlyForReviews() {
        var start = StudySessionStart(kind: .review, cards: 12, studyMode: "fullWord", hardMode: true,
                                      newCards: 2, learningCards: 1, dueCards: 9)
        XCTAssertEqual(start.parameters["due"], "6-10")
        XCTAssertEqual(start.parameters["new"], "2-5")
        XCTAssertEqual(start.parameters["hardMode"], "true")
        start.kind = .quiz
        XCTAssertNil(start.parameters["due"])
    }

    func testReviewEndSendsRatingsAndQuizEndSendsMistakes() {
        var review = StudySessionSummary(kind: .review, finished: false, cards: 10, cardsDone: 4, seconds: 200)
        review.again = 1
        review.good = 3
        XCTAssertEqual(review.parameters["again"], "1")
        XCTAssertEqual(review.parameters["good"], "2-5")
        XCTAssertEqual(review.parameters["finished"], "false")
        XCTAssertNil(review.parameters["mistakes"])

        var quiz = StudySessionSummary(kind: .quiz, finished: true, cards: 5, cardsDone: 5, seconds: 90)
        XCTAssertEqual(quiz.parameters["allCorrect"], "true")
        quiz.mistakes = 2
        XCTAssertEqual(quiz.parameters["allCorrect"], "false")
        XCTAssertNil(quiz.parameters["again"])
    }

    func testOwnPackEventsCarryNoNamesOrText() {
        XCTAssertEqual(AnalyticsEvent.ownVerseAdded(source: .pasted).parameters, ["source": "pasted"])
        XCTAssertEqual(AnalyticsEvent.ankiImported(verses: 34, withHistory: 1, matched: 0).parameters,
                       ["verses": "21-50", "withHistory": "1", "matched": "0"])
        XCTAssertEqual(AnalyticsEvent.packOpened(pack: "Romans", from: .shelf).redactingPacks { $0 == "Romans" },
                       .packOpened(pack: AnalyticsEvent.ownPackLabel, from: .shelf))
    }

    func testSearchNeverCarriesTheQuery() {
        let event = AnalyticsEvent.searchResultOpened(rank: 3, matchedOnReference: false)
        XCTAssertEqual(event.parameters, ["rank": "2-5", "matchedOn": "text"])
        let search = AnalyticsEvent.searchPerformed(results: 7)
        XCTAssertEqual(search.name, "Search.performed")
        XCTAssertEqual(search.parameters, ["results": "6-10"])
    }

    func testReviewStartSeparatesKnownCardsAndEarlierReviews() {
        var start = StudySessionStart(kind: .review, cards: 7, studyMode: "firstLetter", hardMode: false,
                                      newCards: 2, knownCards: 5, reviewedToday: 3)
        XCTAssertEqual(start.parameters["new"], "2-5")
        XCTAssertEqual(start.parameters["known"], "2-5")
        XCTAssertEqual(start.parameters["reviewedToday"], "2-5")
        start.kind = .practice
        XCTAssertNil(start.parameters["known"])
        XCTAssertNil(start.parameters["reviewedToday"])
    }

    func testSimulatorsAndSandboxReceiptsAreTestBuilds() {
        XCTAssertTrue(AnalyticsBuild.isTest(isSimulator: true, receiptName: nil))
        XCTAssertTrue(AnalyticsBuild.isTest(isSimulator: false, receiptName: "sandboxReceipt"))
        XCTAssertFalse(AnalyticsBuild.isTest(isSimulator: false, receiptName: "receipt"))
        XCTAssertFalse(AnalyticsBuild.isTest(isSimulator: false, receiptName: nil))
    }

    func testActiveTimerLeavesOutTimeAway() {
        let start = Date(timeIntervalSince1970: 1_000)
        var timer = ActiveTimer(now: start)
        timer.pause(now: start.addingTimeInterval(20))
        timer.pause(now: start.addingTimeInterval(25))
        XCTAssertEqual(timer.elapsed(now: start.addingTimeInterval(4_000)), 20)
        timer.resume(now: start.addingTimeInterval(4_000))
        timer.resume(now: start.addingTimeInterval(4_005))
        XCTAssertEqual(timer.elapsed(now: start.addingTimeInterval(4_010)), 30)
    }
}
