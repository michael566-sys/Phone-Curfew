#if os(iOS)
import Foundation

public enum ShieldHitKind: String, Sendable {
    /// The block screen was shown.
    case view
    /// A button on the block screen was tapped.
    case tap
}

/// All state shared between the app and its extensions, stored in the App Group.
public final class SharedStore: @unchecked Sendable {
    public static let shared = SharedStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(suiteName: String = AppGroup.identifier) {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    private enum Key {
        static let settings = "settings"
        static let pendingSettings = "pendingSettings"
        static let unlockState = "unlockState"
        static let partner = "partner"
        static let daytimeTargets = "daytimeTargets"
        static let daytimeShielded = "daytimeShielded"
        static func hits(_ kind: ShieldHitKind, _ day: String) -> String { "hits.\(kind.rawValue).\(day)" }
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? encoder.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    public var settings: CurfewSettings {
        get { load(Key.settings) ?? CurfewSettings() }
        set { save(newValue, Key.settings) }
    }

    public var pendingSettings: PendingSettings? {
        get { load(Key.pendingSettings) }
        set { save(newValue, Key.pendingSettings) }
    }

    public var unlockState: UnlockState {
        get { load(Key.unlockState) ?? .idle }
        set { save(newValue, Key.unlockState) }
    }

    public var partner: PartnerRecord? {
        get { load(Key.partner) }
        set { save(newValue, Key.partner) }
    }

    /// Daytime event name → what to shield when that event fires.
    public var daytimeTargets: [String: ShieldTarget] {
        get { load(Key.daytimeTargets) ?? [:] }
        set { save(newValue, Key.daytimeTargets) }
    }

    /// Targets whose daily budget is used up today.
    public var daytimeShielded: [ShieldTarget] {
        get { load(Key.daytimeShielded) ?? [] }
        set { save(newValue, Key.daytimeShielded) }
    }

    // MARK: Blocked-attempt counters (one key per kind per local day)

    public func recordShieldHit(_ kind: ShieldHitKind, at date: Date = Date(), clock: CurfewClock = .live) {
        let key = Key.hits(kind, Self.dayKey(date, clock: clock))
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    public func shieldHits(_ kind: ShieldHitKind, on date: Date, clock: CurfewClock = .live) -> Int {
        defaults.integer(forKey: Key.hits(kind, Self.dayKey(date, clock: clock)))
    }

    /// Sum of hits over the `days` local days ending today.
    public func shieldHits(_ kind: ShieldHitKind, lastDays days: Int, now: Date = Date(), clock: CurfewClock = .live) -> Int {
        let calendar = clock.calendar
        return (0..<days).reduce(0) { total, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return total }
            return total + shieldHits(kind, on: day, clock: clock)
        }
    }

    static func dayKey(_ date: Date, clock: CurfewClock) -> String {
        let parts = clock.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
#endif
