import CurfewKit
import ManagedSettings

/// Handles taps on the block screen. There is no "ignore limit" button: every action closes the app.
final class CurfewShieldAction: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ completionHandler: (ShieldActionResponse) -> Void) {
        SharedStore.shared.recordShieldHit(.tap)
        completionHandler(.close)
    }
}
