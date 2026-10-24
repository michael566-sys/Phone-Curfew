#if os(iOS)
import Foundation

/// Brings shields and unlock state in line with the rules. Safe to call from any target.
public enum CurfewEnforcer {
    @discardableResult
    public static func reconcile(
        now: Date = Date(),
        store: SharedStore = .shared,
        clock: CurfewClock = .live
    ) -> UnlockState {
        let settings = applyDuePendingSettings(now: now, store: store)
        let machine = UnlockMachine(rules: settings.rules, clock: clock)

        let state = machine.advance(store.unlockState, now: now)
        if state != store.unlockState { store.unlockState = state }

        if machine.isBedtime(at: now) && !machine.isUnlocked(state) {
            ShieldApplier.applyBedtime(settings)
        } else {
            ShieldApplier.clearBedtime()
        }
        ShieldApplier.applyStrict(settings.strictMode)
        return state
    }

    /// Applies a delayed strict-mode change once its 24 hours are up.
    @discardableResult
    public static func applyDuePendingSettings(now: Date = Date(), store: SharedStore = .shared) -> CurfewSettings {
        guard let pending = store.pendingSettings, now >= pending.effectiveAt else { return store.settings }
        store.settings = pending.settings
        store.pendingSettings = nil
        try? CurfewScheduler.startMonitoring(pending.settings, store: store)
        return pending.settings
    }

    /// Saves new settings, or queues them if strict mode says they must wait.
    public static func submit(
        _ new: CurfewSettings,
        now: Date = Date(),
        store: SharedStore = .shared,
        clock: CurfewClock = .live
    ) throws -> SettingsChangeDecision {
        let old = store.settings
        let decision = StrictPolicy.decide(
            strictEnabled: old.strictMode,
            isBedtime: UnlockMachine(rules: old.rules, clock: clock).isBedtime(at: now),
            isTightening: new.isTightening(from: old),
            now: now
        )
        switch decision {
        case .applyNow:
            store.settings = new
            store.pendingSettings = nil
            try CurfewScheduler.startMonitoring(new, store: store)
            reconcile(now: now, store: store, clock: clock)
        case let .delayUntil(date):
            store.pendingSettings = PendingSettings(settings: new, effectiveAt: date)
        case .rejectedDuringBedtime:
            break
        }
        return decision
    }
}
#endif
