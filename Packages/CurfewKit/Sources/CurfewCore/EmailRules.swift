import Foundation

/// Lowercases, strips `+tags`, removes Gmail dots and maps googlemail.com to gmail.com.
/// Returns nil for anything that doesn't look like an address.
public func normalizeEmail(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2 else { return nil }

    var local = String(parts[0])
    var domain = String(parts[1])
    guard !local.isEmpty,
          domain.contains("."),
          !domain.hasPrefix("."), !domain.hasSuffix("."),
          !domain.contains(".."),
          !trimmed.contains(where: \.isWhitespace)
    else { return nil }

    if let plus = local.firstIndex(of: "+") {
        local = String(local[..<plus])
    }
    if domain == "googlemail.com" { domain = "gmail.com" }
    if domain == "gmail.com" { local.removeAll { $0 == "." } }
    guard !local.isEmpty else { return nil }
    return "\(local)@\(domain)"
}

public enum PartnerRejection: Error, Equatable, Sendable {
    case invalidAddress
    case ownAddress
    case ownDomain
    case disposableDomain
}

/// Local checks run before an invite is sent. The backend repeats them.
public struct PartnerValidator: Sendable {
    public static let publicProviders: Set<String> = [
        "gmail.com", "outlook.com", "hotmail.com", "live.com", "msn.com",
        "yahoo.com", "icloud.com", "me.com", "mac.com", "aol.com",
        "proton.me", "protonmail.com", "gmx.com", "gmx.de", "yandex.com",
        "qq.com", "163.com", "126.com", "zoho.com", "fastmail.com",
    ]

    public static let disposableDomains: Set<String> = [
        "mailinator.com", "guerrillamail.com", "10minutemail.com", "temp-mail.org",
        "yopmail.com", "trashmail.com", "sharklasers.com", "getnada.com",
        "dispostable.com", "maildrop.cc", "tempmail.com", "throwawaymail.com",
    ]

    public init() {}

    /// Returns the normalized partner address, or throws why it was rejected.
    public func validate(partner: String, myEmails: [String]) throws -> String {
        guard let candidate = normalizeEmail(partner) else { throw PartnerRejection.invalidAddress }
        let mine = myEmails.compactMap(normalizeEmail)
        if mine.contains(candidate) { throw PartnerRejection.ownAddress }

        let domain = Self.domain(of: candidate)
        if Self.disposableDomains.contains(domain) { throw PartnerRejection.disposableDomain }

        let ownedCustomDomains = Set(mine.map(Self.domain(of:))).subtracting(Self.publicProviders)
        if ownedCustomDomains.contains(domain) { throw PartnerRejection.ownDomain }
        return candidate
    }

    static func domain(of email: String) -> String {
        String(email.split(separator: "@").last ?? "")
    }
}
