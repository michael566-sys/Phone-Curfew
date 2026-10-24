import Foundation

/// Timing rules for the curfew and early unlocks.
public struct CurfewRules: Codable, Hashable, Sendable {
    public var night: NightWindow
    public var unlockWait: TimeInterval
    public var readyWindow: TimeInterval
    public var unlockedWindow: TimeInterval

    public init(
        night: NightWindow = .default,
        unlockWait: TimeInterval = 3 * 3600,
        readyWindow: TimeInterval = 15 * 60,
        unlockedWindow: TimeInterval = 15 * 60
    ) {
        self.night = night
        self.unlockWait = unlockWait
        self.readyWindow = readyWindow
        self.unlockedWindow = unlockedWindow
    }

    /// Last wall-clock time a request is accepted (wake minus the wait, 03:30 by default).
    public var requestCutoff: WallClockTime {
        night.end.adding(minutes: -Int(unlockWait / 60))
    }
}

/// idle → waiting (3h) → ready (15 min) → unlocked (15 min) → idle, plus expired and refused.
public enum UnlockState: Codable, Hashable, Sendable {
    case idle
    case waiting(requestedAt: Date, readyAt: Date)
    case ready(until: Date)
    case unlocked(until: Date)
    case expired
    case refused(until: Date)
}

public enum UnlockError: Error, Equatable, Sendable {
    case notBedtime
    case alreadyInProgress
    case notReady
}

/// Pure state transitions. Callers pass in "now" (server time when available).
public struct UnlockMachine: Sendable {
    public var rules: CurfewRules
    public var clock: CurfewClock

    public init(rules: CurfewRules, clock: CurfewClock = .live) {
        self.rules = rules
        self.clock = clock
    }

    public func isBedtime(at now: Date) -> Bool {
        rules.night.contains(clock.wallClock(at: now))
    }

    /// The next wake time (06:30 local) after `now`.
    public func nextWake(after now: Date) -> Date {
        clock.nextDate(matching: rules.night.end, after: now)
    }

    public func isUnlocked(_ state: UnlockState) -> Bool {
        if case .unlocked = state { return true }
        return false
    }

    /// Applies time-based transitions.
    public func advance(_ state: UnlockState, now: Date) -> UnlockState {
        // Outside bedtime there is nothing to unlock, so every state resets.
        guard isBedtime(at: now) else { return .idle }

        switch state {
        case .idle, .expired:
            return state
        case let .waiting(_, readyAt):
            let readyUntil = readyAt.addingTimeInterval(rules.readyWindow)
            if now >= readyUntil { return .expired }
            if now >= readyAt { return .ready(until: readyUntil) }
            return state
        case let .ready(until):
            return now >= until ? .expired : state
        case let .unlocked(until):
            return now >= until ? .idle : state
        case let .refused(until):
            return now >= until ? .idle : state
        }
    }

    /// Starts the 3-hour wait, or returns `.refused` when the unlock would land after wake time.
    public func request(_ state: UnlockState, now: Date) throws -> UnlockState {
        let current = advance(state, now: now)
        switch current {
        case .idle, .expired:
            break
        case .refused:
            return current
        default:
            throw UnlockError.alreadyInProgress
        }
        guard isBedtime(at: now) else { throw UnlockError.notBedtime }

        let wake = nextWake(after: now)
        let readyAt = now.addingTimeInterval(rules.unlockWait)
        guard readyAt <= wake else { return .refused(until: wake) }
        return .waiting(requestedAt: now, readyAt: readyAt)
    }

    public func cancel(_ state: UnlockState) -> UnlockState {
        if case .waiting = state { return .idle }
        return state
    }

    /// Call after the partner code or device passcode has been verified.
    public func completeUnlock(_ state: UnlockState, now: Date) throws -> UnlockState {
        guard case .ready = advance(state, now: now) else { throw UnlockError.notReady }
        return .unlocked(until: now.addingTimeInterval(rules.unlockedWindow))
    }
}
