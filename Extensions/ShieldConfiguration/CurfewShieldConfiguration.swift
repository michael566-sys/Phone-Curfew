import CurfewKit
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the block screen shown when a shielded app or site is opened.
final class CurfewShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let store = SharedStore.shared
        store.recordShieldHit(.view)

        let settings = store.settings
        let clock = CurfewClock.live
        let now = Date()
        let machine = UnlockMachine(rules: settings.rules, clock: clock)

        let title: String
        let subtitle: String
        if machine.isBedtime(at: now) {
            let wake = machine.nextWake(after: now)
            title = "It's past \(clock.display(settings.night.start)) — go to sleep"
            var lines = ["Apps unlock at \(clock.display(settings.night.end)) (in \(formatCountdown(wake.timeIntervalSince(now))))."]
            switch machine.advance(store.unlockState, now: now) {
            case let .waiting(_, readyAt):
                lines.append("Unlock request: \(formatCountdown(readyAt.timeIntervalSince(now))) left to wait.")
            case .ready:
                lines.append("Your unlock is ready. Open Phone Curfew to finish it.")
            case .refused:
                lines.append("It's too close to wake time to unlock early.")
            default:
                break
            }
            subtitle = lines.joined(separator: "\n")
        } else {
            title = "Daily limit reached"
            subtitle = "You've used your \(settings.dailyBudgetMinutes) minutes for today. It resets at midnight."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.07, green: 0.08, blue: 0.18, alpha: 1),
            icon: UIImage(systemName: "moon.zzz.fill"),
            title: .init(text: title, color: .white),
            subtitle: .init(text: subtitle, color: UIColor.white.withAlphaComponent(0.8)),
            primaryButtonLabel: .init(text: "Close", color: .white),
            primaryButtonBackgroundColor: .systemIndigo,
            secondaryButtonLabel: nil
        )
    }
}
