import Foundation

public enum SettingsChangeDecision: Equatable, Sendable {
    case applyNow
    case delayUntil(Date)
    case rejectedDuringBedtime
}

/// Strict mode: settings are read-only at bedtime, and loosening changes wait 24 hours.
public enum StrictPolicy {
    public static let loosenDelay: TimeInterval = 24 * 3600

    public static func decide(
        strictEnabled: Bool,
        isBedtime: Bool,
        isTightening: Bool,
        now: Date
    ) -> SettingsChangeDecision {
        guard strictEnabled else { return .applyNow }
        if isBedtime { return .rejectedDuringBedtime }
        return isTightening ? .applyNow : .delayUntil(now.addingTimeInterval(loosenDelay))
    }
}

/// Fixed limits shared with the backend.
public enum PartnerLimits {
    public static let partnerChangeDelay: TimeInterval = 7 * 86_400
    public static let codeExpiry: TimeInterval = 10 * 60
    public static let codeMaxAttempts = 3
}
