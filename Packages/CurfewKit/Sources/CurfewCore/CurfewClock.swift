import Foundation

/// The single place where wall-clock rules meet real dates.
/// `live` fetches the phone's time zone fresh on every call, so rules follow travel and DST.
public struct CurfewClock: Sendable {
    private let makeCalendar: @Sendable () -> Calendar

    public init(calendar: @escaping @Sendable () -> Calendar) {
        makeCalendar = calendar
    }

    public static let live = CurfewClock {
        NSTimeZone.resetSystemTimeZone()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.locale = Locale.current
        return calendar
    }

    /// A clock pinned to one zone. Used by tests.
    public static func fixed(_ timeZone: TimeZone) -> CurfewClock {
        CurfewClock {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar
        }
    }

    public var calendar: Calendar { makeCalendar() }

    public func wallClock(at date: Date) -> WallClockTime {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return WallClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// The next moment after `date` when the wall clock reads `time`.
    public func nextDate(matching time: WallClockTime, after date: Date) -> Date {
        var parts = time.dateComponents
        parts.second = 0
        return calendar.nextDate(
            after: date,
            matching: parts,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? date.addingTimeInterval(86_400)
    }

    /// Short, localized display string, e.g. "10:30 PM".
    public func display(_ time: WallClockTime) -> String {
        let cal = calendar
        let date = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = cal.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// "3h 05m", "12m", "45s".
public func formatCountdown(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.up)))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    if h > 0 { return String(format: "%dh %02dm", h, m) }
    if m > 0 { return String(format: "%dm %02ds", m, s) }
    return "\(s)s"
}
