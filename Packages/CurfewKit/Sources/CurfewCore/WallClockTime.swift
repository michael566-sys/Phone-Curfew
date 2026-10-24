import Foundation

/// A time of day (hour and minute) with no date or time zone attached.
/// Always evaluated in the phone's current time zone through `CurfewClock`.
public struct WallClockTime: Codable, Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.init(minutesSinceMidnight: hour * 60 + minute)
    }

    public init(minutesSinceMidnight minutes: Int) {
        let wrapped = ((minutes % 1440) + 1440) % 1440
        hour = wrapped / 60
        minute = wrapped % 60
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public func adding(minutes: Int) -> WallClockTime {
        WallClockTime(minutesSinceMidnight: minutesSinceMidnight + minutes)
    }

    /// Hour and minute only, with no time zone, as DeviceActivitySchedule expects.
    public var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    public static func < (lhs: WallClockTime, rhs: WallClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

/// The nightly curfew window, e.g. 22:30 → 06:30. May wrap past midnight.
public struct NightWindow: Codable, Hashable, Sendable {
    public var start: WallClockTime
    public var end: WallClockTime

    public init(start: WallClockTime, end: WallClockTime) {
        self.start = start
        self.end = end
    }

    public static let `default` = NightWindow(
        start: WallClockTime(hour: 22, minute: 30),
        end: WallClockTime(hour: 6, minute: 30)
    )

    public var lengthMinutes: Int {
        ((end.minutesSinceMidnight - start.minutesSinceMidnight) % 1440 + 1440) % 1440
    }

    /// Minutes since the window opened, or nil when `time` is outside it.
    public func minutesIntoWindow(_ time: WallClockTime) -> Int? {
        let into = ((time.minutesSinceMidnight - start.minutesSinceMidnight) % 1440 + 1440) % 1440
        return into < lengthMinutes ? into : nil
    }

    public func contains(_ time: WallClockTime) -> Bool {
        minutesIntoWindow(time) != nil
    }

    /// True when this window covers every minute of `other` (so switching to it is not a loosening).
    public func covers(_ other: NightWindow) -> Bool {
        if other.lengthMinutes == 0 { return true }
        guard let into = minutesIntoWindow(other.start) else { return false }
        return into + other.lengthMinutes <= lengthMinutes
    }
}
