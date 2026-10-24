import CurfewKit
import DeviceActivity
import Foundation

/// Runs in the background at schedule boundaries and usage thresholds.
/// Keep this small: the extension has a tight memory limit.
final class CurfewMonitor: DeviceActivityMonitor {
    private let store = SharedStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case .bedtime:
            // Apply directly rather than through a wall-clock check: callbacks can arrive a few seconds early.
            let settings = CurfewEnforcer.applyDuePendingSettings(store: store)
            let machine = UnlockMachine(rules: settings.rules)
            store.unlockState = machine.advance(store.unlockState, now: Date())
            if !machine.isUnlocked(store.unlockState) {
                ShieldApplier.applyBedtime(settings)
            }
            ShieldApplier.applyStrict(settings.strictMode)
        case .daytime:
            ShieldApplier.clearDaytime(store: store)
        default:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch activity {
        case .bedtime:
            ShieldApplier.clearBedtime()
            store.unlockState = .idle
        case .daytime:
            ShieldApplier.clearDaytime(store: store)
        case .unlockWindow:
            // The 15-minute unlock is over: put the shields back.
            CurfewEnforcer.reconcile(store: store)
            CurfewScheduler.stopUnlockWindow()
        default:
            break
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == .daytime, let target = store.daytimeTargets[event.rawValue] else { return }
        ShieldApplier.addDaytimeShield(target, store: store)
    }
}
