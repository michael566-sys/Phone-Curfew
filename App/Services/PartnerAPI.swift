import Foundation

/// The partner backend (see README "Partner backend").
protocol PartnerAPI: Sendable {
    /// Trusted current instant. Falls back to the device clock when offline.
    func currentTime() async -> Date
    func verifyUnlockCode(_ code: String) async throws -> Bool
}

enum PartnerAPIError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        "The partner server isn't connected yet. Use your device passcode instead."
    }
}

/// Used until the backend exists. Strict mode's automatic-time rule keeps the device clock honest meanwhile.
struct OfflinePartnerAPI: PartnerAPI {
    func currentTime() async -> Date { Date() }

    func verifyUnlockCode(_ code: String) async throws -> Bool {
        throw PartnerAPIError.notConfigured
    }
}
