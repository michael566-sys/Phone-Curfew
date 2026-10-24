#if os(iOS)
import FamilyControls
import Foundation
import ManagedSettings

/// The only code that writes the named ManagedSettings stores.
public enum ShieldApplier {
    public static func applyBedtime(_ settings: CurfewSettings) {
        let store = ManagedSettingsStore(named: .bedtime)
        store.clearAllSettings()

        switch settings.bedtimeMode {
        case .blockSelected:
            let sel = settings.bedtimeSelection
            store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
            store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
            if !sel.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(sel.categoryTokens)
                store.shield.webDomainCategories = .specific(sel.categoryTokens)
            }
        case .blockAllExcept:
            store.shield.applicationCategories = .all(except: settings.allowlist.applicationTokens)
            store.shield.webDomainCategories = .all(except: settings.allowlist.webDomainTokens)
        }
    }

    public static func clearBedtime() {
        ManagedSettingsStore(named: .bedtime).clearAllSettings()
    }

    public static var isBedtimeShieldActive: Bool {
        let shield = ManagedSettingsStore(named: .bedtime).shield
        return shield.applications != nil || shield.applicationCategories != nil
            || shield.webDomains != nil || shield.webDomainCategories != nil
    }

    /// Shields one more target whose daily budget ran out.
    public static func addDaytimeShield(_ target: ShieldTarget, store: SharedStore = .shared) {
        var shielded = store.daytimeShielded
        if !shielded.contains(target) { shielded.append(target) }
        store.daytimeShielded = shielded
        applyDaytime(shielded)
    }

    public static func clearDaytime(store: SharedStore = .shared) {
        store.daytimeShielded = []
        ManagedSettingsStore(named: .daytime).clearAllSettings()
    }

    static func applyDaytime(_ targets: [ShieldTarget]) {
        var apps = Set<ApplicationToken>()
        var categories = Set<ActivityCategoryToken>()
        var domains = Set<WebDomainToken>()
        for target in targets {
            switch target {
            case let .application(token): apps.insert(token)
            case let .category(token): categories.insert(token)
            case let .webDomain(token): domains.insert(token)
            }
        }
        let store = ManagedSettingsStore(named: .daytime)
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.webDomains = domains.isEmpty ? nil : domains
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }

    /// Strict mode: the app can't be deleted and the clock can't be set by hand.
    public static func applyStrict(_ enabled: Bool) {
        let store = ManagedSettingsStore(named: .strict)
        if enabled {
            store.application.denyAppRemoval = true
            store.dateAndTime.requireAutomaticDateAndTime = true
        } else {
            store.clearAllSettings()
        }
    }
}
#endif
