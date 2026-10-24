#if os(iOS)
import DeviceActivity
import FamilyControls
import Foundation

/// Registers DeviceActivity schedules. Components carry no time zone, so they follow local time.
public enum CurfewScheduler {
    public static func startMonitoring(_ settings: CurfewSettings, store: SharedStore = .shared) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.bedtime, .daytime])

        let night = DeviceActivitySchedule(
            intervalStart: settings.night.start.dateComponents,
            intervalEnd: settings.night.end.dateComponents,
            repeats: true
        )
        try center.startMonitoring(.bedtime, during: night)

        // One event per limited item, so each app is shielded on its own when its budget runs out.
        let threshold = DateComponents(minute: max(1, settings.dailyBudgetMinutes))
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        var targets: [String: ShieldTarget] = [:]
        let sel = settings.daytimeSelection

        for (i, token) in sel.applicationTokens.enumerated() {
            let name = "app.\(i)"
            events[.init(name)] = DeviceActivityEvent(applications: [token], threshold: threshold)
            targets[name] = .application(token)
        }
        for (i, token) in sel.categoryTokens.enumerated() {
            let name = "category.\(i)"
            events[.init(name)] = DeviceActivityEvent(categories: [token], threshold: threshold)
            targets[name] = .category(token)
        }
        for (i, token) in sel.webDomainTokens.enumerated() {
            let name = "web.\(i)"
            events[.init(name)] = DeviceActivityEvent(webDomains: [token], threshold: threshold)
            targets[name] = .webDomain(token)
        }
        store.daytimeTargets = targets

        guard !events.isEmpty else { return }
        let day = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try center.startMonitoring(.daytime, during: day, events: events)
    }

    /// A one-off activity whose end re-applies bedtime shields after an unlock.
    /// DeviceActivity needs intervals of at least 15 minutes, so the start is back-dated slightly.
    public static func startUnlockWindow(until end: Date, clock: CurfewClock = .live) throws {
        let calendar = clock.calendar
        let units: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let start = end.addingTimeInterval(-16 * 60)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(units, from: start),
            intervalEnd: calendar.dateComponents(units, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.unlockWindow])
        try center.startMonitoring(.unlockWindow, during: schedule)
    }

    public static func stopUnlockWindow() {
        DeviceActivityCenter().stopMonitoring([.unlockWindow])
    }
}
#endif
