import Combine
import CurfewKit
import FamilyControls
import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var authorization: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    private(set) var settings: CurfewSettings
    private(set) var pending: PendingSettings?
    private(set) var unlockState: UnlockState
    private(set) var partner: PartnerRecord?
    var message: String?

    @ObservationIgnored private let store = SharedStore.shared
    @ObservationIgnored private let api: PartnerAPI
    @ObservationIgnored private var authCancellable: AnyCancellable?
    let clock = CurfewClock.live

    init(api: PartnerAPI = OfflinePartnerAPI()) {
        self.api = api
        settings = store.settings
        pending = store.pendingSettings
        unlockState = store.unlockState
        partner = store.partner
        authCancellable = AuthorizationCenter.shared.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                let wasApproved = self.authorization == .approved
                self.authorization = status
                if status == .approved && !wasApproved { self.startMonitoring() }
            }
    }

    var machine: UnlockMachine { UnlockMachine(rules: settings.rules, clock: clock) }

    func isBedtime(at now: Date = Date()) -> Bool { machine.isBedtime(at: now) }

    // MARK: Lifecycle

    func onLaunch() {
        guard authorization == .approved else { return }
        startMonitoring()
        refresh()
    }

    /// Fallback enforcement: DeviceActivity callbacks can be late, so re-check on every foreground.
    func refresh() {
        guard authorization == .approved else { return }
        unlockState = CurfewEnforcer.reconcile(store: store, clock: clock)
        reload()
    }

    func handleClockChange() {
        startMonitoring()
        refresh()
    }

    private func startMonitoring() {
        do {
            try CurfewScheduler.startMonitoring(store.settings, store: store)
        } catch {
            message = "Couldn't start monitoring: \(error.localizedDescription)"
        }
    }

    private func reload() {
        settings = store.settings
        pending = store.pendingSettings
        unlockState = store.unlockState
        partner = store.partner
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            message = "Screen Time access wasn't granted: \(error.localizedDescription)"
        }
    }

    // MARK: Settings

    func submit(_ new: CurfewSettings) {
        do {
            switch try CurfewEnforcer.submit(new, store: store, clock: clock) {
            case .applyNow:
                message = "Saved."
            case let .delayUntil(date):
                message = "Strict mode: this loosens your rules, so it takes effect \(date.formatted(date: .abbreviated, time: .shortened))."
            case .rejectedDuringBedtime:
                message = "Strict mode: settings can't be changed during bedtime."
            }
        } catch {
            message = "Saved, but monitoring failed to restart: \(error.localizedDescription)"
        }
        reload()
    }

    func cancelPendingChange() {
        store.pendingSettings = nil
        reload()
    }

    func invitePartner(_ email: String) {
        do {
            let normalized = try PartnerValidator().validate(partner: email, myEmails: settings.myEmails)
            if let current = partner, current.email != normalized {
                message = "Changing partners takes 7 days and notifies your current partner. That needs the partner server, which isn't connected yet."
                return
            }
            store.partner = PartnerRecord(email: normalized, status: .invited, addedAt: Date())
            message = "Partner saved. The invite email is sent once the partner server is connected."
        } catch let rejection as PartnerRejection {
            message = rejection.explanation
        } catch {
            message = error.localizedDescription
        }
        reload()
    }

    // MARK: Unlock

    func requestUnlock() async {
        let now = await api.currentTime()
        do {
            store.unlockState = try machine.request(store.unlockState, now: now)
        } catch UnlockError.notBedtime {
            message = "Nothing is locked right now."
        } catch {
            message = "An unlock request is already in progress."
        }
        reload()
    }

    func cancelUnlock() {
        store.unlockState = machine.cancel(store.unlockState)
        reload()
    }

    func unlockWithPasscode() async {
        guard case .ready = machine.advance(store.unlockState, now: await api.currentTime()) else { return }
        let context = LAContext()
        do {
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your apps for 15 minutes") else { return }
            await completeUnlock()
        } catch {
            message = "Passcode check failed."
        }
    }

    func unlockWithPartnerCode(_ code: String) async {
        do {
            guard try await api.verifyUnlockCode(code) else {
                message = "That code isn't right."
                return
            }
            await completeUnlock()
        } catch {
            message = error.localizedDescription
        }
    }

    private func completeUnlock() async {
        let now = await api.currentTime()
        do {
            let state = try machine.completeUnlock(store.unlockState, now: now)
            store.unlockState = state
            ShieldApplier.clearBedtime()
            if case let .unlocked(until) = state {
                try CurfewScheduler.startUnlockWindow(until: until, clock: clock)
            }
        } catch UnlockError.notReady {
            message = "The unlock window has closed."
        } catch {
            // The relock schedule failed; the app's fallback re-applies shields on next open.
            message = "Unlocked, but the automatic relock couldn't be scheduled."
        }
        reload()
    }
}

extension PartnerRejection {
    var explanation: String {
        switch self {
        case .invalidAddress: "That doesn't look like an email address."
        case .ownAddress: "That's one of your own addresses."
        case .ownDomain: "That address is on a domain you own."
        case .disposableDomain: "Disposable email addresses can't be partners."
        }
    }
}
