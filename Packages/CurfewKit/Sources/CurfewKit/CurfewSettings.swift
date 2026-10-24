#if os(iOS)
import FamilyControls
import Foundation
import ManagedSettings

public enum BedtimeMode: String, Codable, CaseIterable, Sendable {
    /// Block the apps in `bedtimeSelection`.
    case blockSelected
    /// Block everything except the apps in `allowlist`.
    case blockAllExcept
}

/// Everything the user configures. Persisted in the App Group.
public struct CurfewSettings: Codable, Equatable {
    public var night: NightWindow = .default
    public var bedtimeMode: BedtimeMode = .blockSelected
    public var bedtimeSelection = FamilyActivitySelection()
    public var allowlist = FamilyActivitySelection()
    public var daytimeSelection = FamilyActivitySelection()
    public var dailyBudgetMinutes: Int = 60
    public var strictMode = false
    public var myEmails: [String] = []

    public init() {}

    public var rules: CurfewRules { CurfewRules(night: night) }

    /// True when `self` is at least as strict as `old` in every respect.
    /// Anything else counts as loosening and waits 24 hours in strict mode.
    public func isTightening(from old: CurfewSettings) -> Bool {
        if old.strictMode && !strictMode { return false }
        if !night.covers(old.night) { return false }

        switch (old.bedtimeMode, bedtimeMode) {
        case (.blockSelected, .blockSelected):
            guard bedtimeSelection.includes(old.bedtimeSelection) else { return false }
        case (.blockAllExcept, .blockAllExcept):
            guard old.allowlist.includes(allowlist) else { return false }
        case (.blockSelected, .blockAllExcept):
            // Blocking everything is stricter, unless a previously blocked app is now allowed.
            guard allowlist.applicationTokens.isDisjoint(with: old.bedtimeSelection.applicationTokens),
                  allowlist.webDomainTokens.isDisjoint(with: old.bedtimeSelection.webDomainTokens)
            else { return false }
        case (.blockAllExcept, .blockSelected):
            return false
        }

        guard daytimeSelection.includes(old.daytimeSelection),
              dailyBudgetMinutes <= old.dailyBudgetMinutes
        else { return false }

        // Removing one of "my emails" could free it up to pose as a partner.
        let oldMine = Set(old.myEmails.compactMap(normalizeEmail))
        let newMine = Set(myEmails.compactMap(normalizeEmail))
        return newMine.isSuperset(of: oldMine)
    }
}

public extension FamilyActivitySelection {
    func includes(_ other: FamilyActivitySelection) -> Bool {
        applicationTokens.isSuperset(of: other.applicationTokens)
            && categoryTokens.isSuperset(of: other.categoryTokens)
            && webDomainTokens.isSuperset(of: other.webDomainTokens)
    }

    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    var itemCount: Int {
        applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }
}

/// A loosening change waiting out the strict-mode delay.
public struct PendingSettings: Codable, Equatable {
    public var settings: CurfewSettings
    public var effectiveAt: Date

    public init(settings: CurfewSettings, effectiveAt: Date) {
        self.settings = settings
        self.effectiveAt = effectiveAt
    }
}

/// One thing a daytime limit can shield.
public enum ShieldTarget: Codable, Hashable {
    case application(ApplicationToken)
    case category(ActivityCategoryToken)
    case webDomain(WebDomainToken)
}

public struct PartnerRecord: Codable, Equatable {
    public enum Status: String, Codable {
        /// Invite created locally; the backend sends and confirms it.
        case invited
        case confirmed
    }

    public var email: String
    public var status: Status
    public var addedAt: Date

    public init(email: String, status: Status, addedAt: Date) {
        self.email = email
        self.status = status
        self.addedAt = addedAt
    }

    /// New partners wait 7 days before they can approve unlocks.
    public func canApprove(at now: Date) -> Bool {
        status == .confirmed && now >= addedAt.addingTimeInterval(PartnerLimits.partnerChangeDelay)
    }
}
#endif
