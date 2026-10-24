import XCTest
@testable import CurfewCore

private let newYork = TimeZone(identifier: "America/New_York")!
private let chicago = TimeZone(identifier: "America/Chicago")!

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0, in tz: TimeZone = newYork) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
}

final class NightWindowTests: XCTestCase {
    let night = NightWindow.default

    func testContainsWrapsMidnight() {
        XCTAssertTrue(night.contains(WallClockTime(hour: 22, minute: 30)))
        XCTAssertTrue(night.contains(WallClockTime(hour: 0, minute: 0)))
        XCTAssertTrue(night.contains(WallClockTime(hour: 6, minute: 29)))
        XCTAssertFalse(night.contains(WallClockTime(hour: 6, minute: 30)))
        XCTAssertFalse(night.contains(WallClockTime(hour: 22, minute: 29)))
        XCTAssertFalse(night.contains(WallClockTime(hour: 12, minute: 0)))
    }

    func testCovers() {
        let longer = NightWindow(start: .init(hour: 22, minute: 0), end: .init(hour: 7, minute: 0))
        let shorter = NightWindow(start: .init(hour: 23, minute: 0), end: .init(hour: 6, minute: 0))
        XCTAssertTrue(longer.covers(night))
        XCTAssertTrue(night.covers(night))
        XCTAssertFalse(shorter.covers(night))
        XCTAssertFalse(NightWindow(start: .init(hour: 22, minute: 0), end: .init(hour: 6, minute: 0)).covers(night))
    }

    func testRequestCutoffIsWakeMinusWait() {
        XCTAssertEqual(CurfewRules().requestCutoff, WallClockTime(hour: 3, minute: 30))
    }
}

final class UnlockMachineTests: XCTestCase {
    let machine = UnlockMachine(rules: CurfewRules(), clock: .fixed(newYork))

    func testReadmeTable() throws {
        // Request at → earliest unlock
        let cases: [(Date, Date)] = [
            (date(2026, 10, 20, 22, 30), date(2026, 10, 21, 1, 30)),
            (date(2026, 10, 21, 1, 0), date(2026, 10, 21, 4, 0)),
            (date(2026, 10, 21, 3, 30), date(2026, 10, 21, 6, 30)),
        ]
        for (requested, expected) in cases {
            let state = try machine.request(.idle, now: requested)
            XCTAssertEqual(state, .waiting(requestedAt: requested, readyAt: expected))
        }
    }

    func testRefusedAfterCutoffUntilWake() throws {
        let now = date(2026, 10, 21, 3, 30, 1)
        XCTAssertEqual(try machine.request(.idle, now: now), .refused(until: date(2026, 10, 21, 6, 30)))
    }

    func testRequestOutsideBedtimeThrows() {
        XCTAssertThrowsError(try machine.request(.idle, now: date(2026, 10, 21, 15, 0))) {
            XCTAssertEqual($0 as? UnlockError, .notBedtime)
        }
    }

    func testDuplicateRequestThrows() throws {
        let now = date(2026, 10, 20, 23, 0)
        let waiting = try machine.request(.idle, now: now)
        XCTAssertThrowsError(try machine.request(waiting, now: now.addingTimeInterval(60))) {
            XCTAssertEqual($0 as? UnlockError, .alreadyInProgress)
        }
    }

    func testFullLifecycle() throws {
        let start = date(2026, 10, 20, 23, 0)
        var state = try machine.request(.idle, now: start)

        // Still waiting just before 3h.
        XCTAssertEqual(machine.advance(state, now: start.addingTimeInterval(3 * 3600 - 1)), state)
        XCTAssertThrowsError(try machine.completeUnlock(state, now: start.addingTimeInterval(3600)))

        // Ready at 3h, for 15 minutes.
        let readyAt = start.addingTimeInterval(3 * 3600)
        state = machine.advance(state, now: readyAt)
        XCTAssertEqual(state, .ready(until: readyAt.addingTimeInterval(15 * 60)))

        // Unlock lasts 15 minutes, then back to idle.
        let unlockTime = readyAt.addingTimeInterval(60)
        state = try machine.completeUnlock(state, now: unlockTime)
        XCTAssertEqual(state, .unlocked(until: unlockTime.addingTimeInterval(15 * 60)))
        XCTAssertEqual(machine.advance(state, now: unlockTime.addingTimeInterval(15 * 60)), .idle)
    }

    func testReadyExpires() throws {
        let start = date(2026, 10, 20, 23, 0)
        let waiting = try machine.request(.idle, now: start)
        XCTAssertEqual(machine.advance(waiting, now: start.addingTimeInterval(3 * 3600 + 15 * 60)), .expired)
        // A fresh request is allowed after expiry.
        XCTAssertNoThrow(try machine.request(.expired, now: start.addingTimeInterval(3 * 3600 + 16 * 60)))
    }

    func testCancel() throws {
        let waiting = try machine.request(.idle, now: date(2026, 10, 20, 23, 0))
        XCTAssertEqual(machine.cancel(waiting), .idle)
    }

    func testEverythingResetsAfterWake() throws {
        let waiting = try machine.request(.idle, now: date(2026, 10, 21, 3, 0))
        XCTAssertEqual(machine.advance(waiting, now: date(2026, 10, 21, 6, 30)), .idle)
        XCTAssertEqual(machine.advance(.refused(until: date(2026, 10, 21, 6, 30)), now: date(2026, 10, 21, 6, 30)), .idle)
    }

    func testWaitIsElapsedTimeAcrossFallBack() throws {
        // 2026-11-01: clocks fall back 02:00 EDT → 01:00 EST.
        let start = date(2026, 11, 1, 0, 30) // EDT
        let state = try machine.request(.idle, now: start)
        guard case let .waiting(_, readyAt) = state else { return XCTFail() }
        XCTAssertEqual(readyAt.timeIntervalSince(start), 3 * 3600)
        // Three real hours later the wall clock reads 02:30 EST.
        XCTAssertEqual(machine.clock.wallClock(at: readyAt), WallClockTime(hour: 2, minute: 30))
    }

    func testCutoffStaysWallClockOnSpringForward() throws {
        // 2026-03-08: clocks jump 02:00 EST → 03:00 EDT. Cutoff is still 03:30 on the wall.
        XCTAssertNoThrow(try machine.request(.idle, now: date(2026, 3, 8, 3, 30)))
        if case .waiting = try machine.request(.idle, now: date(2026, 3, 8, 3, 31)) { XCTFail("should refuse") }
    }

    func testTimeZoneChangeMidWaitKeepsElapsedWait() throws {
        let start = date(2026, 10, 20, 23, 0)                 // 23:00 New York
        let waiting = try machine.request(.idle, now: start)
        let moved = UnlockMachine(rules: CurfewRules(), clock: .fixed(chicago))
        // 3 real hours later is 01:00 in Chicago: still bedtime, now ready.
        let readyAt = start.addingTimeInterval(3 * 3600)
        XCTAssertEqual(moved.advance(waiting, now: readyAt), .ready(until: readyAt.addingTimeInterval(15 * 60)))
    }
}

final class EmailTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(normalizeEmail("  You+X@Gmail.com "), "you@gmail.com")
        XCTAssertEqual(normalizeEmail("y.o.u@googlemail.com"), "you@gmail.com")
        XCTAssertEqual(normalizeEmail("first.last+tag@example.com"), "first.last@example.com")
        XCTAssertNil(normalizeEmail("not-an-email"))
        XCTAssertNil(normalizeEmail("a@b@c.com"))
        XCTAssertNil(normalizeEmail("+tag@gmail.com"))
        XCTAssertNil(normalizeEmail("me@localhost"))
    }

    func testPartnerValidation() throws {
        let v = PartnerValidator()
        let mine = ["you@gmail.com", "me@mydomain.dev"]
        XCTAssertThrowsError(try v.validate(partner: "Y.O.U+partner@gmail.com", myEmails: mine)) {
            XCTAssertEqual($0 as? PartnerRejection, .ownAddress)
        }
        XCTAssertThrowsError(try v.validate(partner: "other@mydomain.dev", myEmails: mine)) {
            XCTAssertEqual($0 as? PartnerRejection, .ownDomain)
        }
        XCTAssertThrowsError(try v.validate(partner: "x@mailinator.com", myEmails: mine)) {
            XCTAssertEqual($0 as? PartnerRejection, .disposableDomain)
        }
        XCTAssertThrowsError(try v.validate(partner: "nope", myEmails: mine)) {
            XCTAssertEqual($0 as? PartnerRejection, .invalidAddress)
        }
        // Public providers are exempt from the domain rule.
        XCTAssertEqual(try v.validate(partner: "Friend@Gmail.com", myEmails: mine), "friend@gmail.com")
    }
}

final class StrictPolicyTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)

    func testDecisions() {
        XCTAssertEqual(StrictPolicy.decide(strictEnabled: false, isBedtime: true, isTightening: false, now: now), .applyNow)
        XCTAssertEqual(StrictPolicy.decide(strictEnabled: true, isBedtime: true, isTightening: true, now: now), .rejectedDuringBedtime)
        XCTAssertEqual(StrictPolicy.decide(strictEnabled: true, isBedtime: false, isTightening: true, now: now), .applyNow)
        XCTAssertEqual(StrictPolicy.decide(strictEnabled: true, isBedtime: false, isTightening: false, now: now),
                       .delayUntil(now.addingTimeInterval(24 * 3600)))
    }
}
