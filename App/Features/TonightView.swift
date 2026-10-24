import CurfewKit
import SwiftUI

/// Current curfew status and the early-unlock flow.
struct TonightView: View {
    @Environment(AppModel.self) private var model
    @State private var partnerCode = ""

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                let state = model.machine.advance(model.unlockState, now: now)
                List {
                    statusSection(now: now)
                    if model.isBedtime(at: now) {
                        unlockSection(state: state, now: now)
                    }
                    if let message = model.message {
                        Section { Text(message).font(.footnote) }
                    }
                }
                .onChange(of: state) { _, _ in model.refresh() }
            }
            .navigationTitle("Tonight")
        }
    }

    @ViewBuilder
    private func statusSection(now: Date) -> some View {
        let night = model.settings.night
        let clock = model.clock
        Section {
            if model.isBedtime(at: now) {
                Label("Bedtime — apps are locked", systemImage: "lock.fill")
                    .font(.headline)
                Text("Unlocks at \(clock.display(night.end)), in \(formatCountdown(model.machine.nextWake(after: now).timeIntervalSince(now))).")
            } else {
                Label("Daytime", systemImage: "sun.max.fill").font(.headline)
                let start = clock.nextDate(matching: night.start, after: now)
                Text("Bedtime starts at \(clock.display(night.start)), in \(formatCountdown(start.timeIntervalSince(now))).")
            }
            if model.settings.strictMode {
                Label("Strict mode is on", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.indigo)
            }
        }
    }

    @ViewBuilder
    private func unlockSection(state: UnlockState, now: Date) -> some View {
        Section("Early unlock") {
            switch state {
            case .idle, .expired:
                if case .expired = state {
                    Text("Your last unlock window expired.").foregroundStyle(.secondary)
                }
                Text("Unlocking early takes a 3-hour wait. Requests after \(model.clock.display(model.settings.rules.requestCutoff)) are refused.")
                    .font(.footnote)
                Button("Request unlock") { Task { await model.requestUnlock() } }

            case let .waiting(_, readyAt):
                Text("Waiting: \(formatCountdown(readyAt.timeIntervalSince(now))) left")
                    .font(.title3.monospacedDigit())
                Button("Cancel request", role: .destructive) { model.cancelUnlock() }

            case let .ready(until):
                Text("Ready. Finish within \(formatCountdown(until.timeIntervalSince(now))).")
                    .font(.title3.monospacedDigit())
                Button("Unlock with device passcode") { Task { await model.unlockWithPasscode() } }
                if model.partner?.canApprove(at: now) == true {
                    TextField("Partner code", text: $partnerCode)
                        .keyboardType(.numberPad)
                    Button("Unlock with partner code") {
                        Task { await model.unlockWithPartnerCode(partnerCode) }
                    }
                    .disabled(partnerCode.isEmpty)
                }

            case let .unlocked(until):
                Label("Unlocked for \(formatCountdown(until.timeIntervalSince(now)))", systemImage: "lock.open.fill")
                    .font(.title3.monospacedDigit())

            case let .refused(until):
                Text("It's too close to wake time. Apps unlock at \(until.formatted(date: .omitted, time: .shortened)).")
            }
        }
    }
}
