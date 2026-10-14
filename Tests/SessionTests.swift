import XCTest
@testable import FocusFeed

final class SessionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }
    private func running(_ s: Session, _ m: Double) -> TimeInterval? {
        if case let .running(_, r) = s.phase(at: at(m)) { return r }
        return nil
    }

    func testFreshSessionNeedsSetup() {
        XCTAssertEqual(Session().phase(at: t0), .setup)
    }
    func testStartRunsWithNormalizedTerms() {
        var s = Session()
        XCTAssertTrue(s.start(terms: ["  Gaming ", "", "lo+fi  Music"], minutes: 15, now: t0))
        XCTAssertEqual(s.phase(at: at(5)), .running(terms: ["gaming", "lo fi music"], remaining: 600))
    }
    func testBudgetMustBe1To90Minutes() {
        var s = Session()
        XCTAssertFalse(s.start(terms: [], minutes: 0, now: t0))
        XCTAssertFalse(s.start(terms: [], minutes: 91, now: t0))
        XCTAssertEqual(s.phase(at: t0), .setup)
        XCTAssertTrue(s.start(terms: [], minutes: 90, now: t0))
    }
    func testCannotStartWhileRunningOrLocked() {
        var s = Session()
        s.start(terms: [], minutes: 10, now: t0)
        XCTAssertFalse(s.start(terms: [], minutes: 10, now: at(1)))
        XCTAssertFalse(s.start(terms: [], minutes: 10, now: at(20)))   // locked
    }
    func testExhaustedBudgetLocksFourTimesBudget() {
        var s = Session()
        s.start(terms: ["x"], minutes: 15, now: t0)
        XCTAssertEqual(s.phase(at: at(15)), .locked(until: at(15 + 60)))
    }
    func testOnlyActiveTimeCounts() {
        var s = Session()
        s.start(terms: [], minutes: 10, now: t0)
        s.pause(now: at(4))
        s.resume(now: at(24))                    // 20 min away, under the timeout
        XCTAssertEqual(running(s, 25), 5 * 60)
        XCTAssertEqual(s.phase(at: at(30)), .locked(until: at(30 + 40)))
    }
    func testWarningWindowIsTheLastMinute() {
        var s = Session()
        s.start(terms: [], minutes: 10, now: t0)
        XCTAssertGreaterThan(running(s, 8.9)!, Session.warningLead)
        XCTAssertLessThanOrEqual(running(s, 9)!, Session.warningLead)
    }
    func testThirtyMinutesInBackgroundEndsSessionWithLockOfFourTimesUsed() {
        var s = Session()
        s.start(terms: [], minutes: 30, now: t0)
        s.pause(now: at(10))
        XCTAssertNotNil(running(s, 39))
        XCTAssertEqual(s.phase(at: at(40)), .locked(until: at(10 + 40)))
        s.resume(now: at(45))
        XCTAssertEqual(s.phase(at: at(45)), .locked(until: at(50)))
    }
    func testLockExpiresBackToSetup() {
        var s = Session()
        s.start(terms: [], minutes: 1, now: t0)
        XCTAssertEqual(s.phase(at: at(4.9)), .locked(until: at(5)))
        XCTAssertEqual(s.phase(at: at(5)), .setup)
        XCTAssertTrue(s.start(terms: [], minutes: 5, now: at(5)))
    }
    func testPausedTimeDoesNotExhaustBudget() {
        var s = Session()
        s.start(terms: [], minutes: 10, now: t0)
        s.pause(now: at(9))
        XCTAssertEqual(running(s, 20), 60)        // budget would be over if wall-clock counted
    }
    func testCodableRoundTripKeepsState() throws {
        var s = Session()
        s.start(terms: ["music"], minutes: 20, now: t0)
        s.pause(now: at(5))
        let back = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
        XCTAssertEqual(back.phase(at: at(6)), .running(terms: ["music"], remaining: 15 * 60))
    }
}
