import CurfewKit
import FamilyControls
import SwiftUI

/// Edits a draft copy of the settings; Save runs it through the strict-mode rules.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft = CurfewSettings()
    @State private var pickingBedtime = false
    @State private var pickingAllowlist = false
    @State private var pickingDaytime = false
    @State private var confirmStrict = false

    private var readOnly: Bool { model.settings.strictMode && model.isBedtime() }

    var body: some View {
        NavigationStack {
            Form {
                if let pending = model.pending {
                    Section {
                        Text("A change is waiting for strict mode's 24-hour delay. It applies \(pending.effectiveAt.formatted(date: .abbreviated, time: .shortened)).")
                        Button("Cancel pending change", role: .destructive) { model.cancelPendingChange() }
                    }
                }
                if readOnly {
                    Section { Text("Strict mode: settings are read-only during bedtime.").foregroundStyle(.secondary) }
                }

                Section("Schedule") {
                    DatePicker("Bedtime", selection: wallClock(\.night.start), displayedComponents: .hourAndMinute)
                    DatePicker("Wake", selection: wallClock(\.night.end), displayedComponents: .hourAndMinute)
                }

                Section {
                    Picker("Mode", selection: $draft.bedtimeMode) {
                        Text("Block selected apps").tag(BedtimeMode.blockSelected)
                        Text("Block all except").tag(BedtimeMode.blockAllExcept)
                    }
                    if draft.bedtimeMode == .blockSelected {
                        selectionRow("Blocked at bedtime", draft.bedtimeSelection) { pickingBedtime = true }
                    } else {
                        selectionRow("Always allowed", draft.allowlist) { pickingAllowlist = true }
                    }
                } header: {
                    Text("Bedtime")
                } footer: {
                    if draft.bedtimeMode == .blockAllExcept {
                        Text("Add Phone, Messages and Clock so calls and alarms keep working.")
                    }
                }

                Section("Daytime limits") {
                    selectionRow("Limited apps", draft.daytimeSelection) { pickingDaytime = true }
                    Stepper("\(draft.dailyBudgetMinutes) min per app per day", value: $draft.dailyBudgetMinutes, in: 5...480, step: 5)
                }

                Section {
                    Toggle("Strict mode", isOn: strictBinding)
                } footer: {
                    Text("Stops the app being deleted and forces automatic time. Loosening any rule then waits 24 hours, and nothing can be changed during bedtime.")
                }

                Section {
                    NavigationLink("Accountability partner") { PartnerView() }
                }

                if let message = model.message {
                    Section { Text(message).font(.footnote) }
                }
            }
            .disabled(readOnly)
            .navigationTitle("Settings")
            .toolbar {
                Button("Save") { model.submit(draft) }
                    .disabled(draft == model.settings || readOnly)
            }
            .familyActivityPicker(isPresented: $pickingBedtime, selection: $draft.bedtimeSelection)
            .familyActivityPicker(isPresented: $pickingAllowlist, selection: $draft.allowlist)
            .familyActivityPicker(isPresented: $pickingDaytime, selection: $draft.daytimeSelection)
            .confirmationDialog("Turn on strict mode?", isPresented: $confirmStrict, titleVisibility: .visible) {
                Button("Turn on") { draft.strictMode = true }
            } message: {
                Text("Turning it off again will take 24 hours.")
            }
            .onAppear { draft = model.settings }
            .onChange(of: model.settings) { _, saved in draft = saved }
        }
    }

    private var strictBinding: Binding<Bool> {
        Binding(
            get: { draft.strictMode },
            set: { on in
                if on && !model.settings.strictMode { confirmStrict = true } else { draft.strictMode = on }
            }
        )
    }

    private func wallClock(_ keyPath: WritableKeyPath<CurfewSettings, WallClockTime>) -> Binding<Date> {
        Binding(
            get: {
                let t = draft[keyPath: keyPath]
                return model.clock.calendar.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                draft[keyPath: keyPath] = model.clock.wallClock(at: date)
            }
        )
    }

    private func selectionRow(_ title: String, _ selection: FamilyActivitySelection, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).foregroundStyle(.primary)
                    Spacer()
                    Text(selection.isEmpty ? "None" : "\(selection.itemCount) selected")
                        .foregroundStyle(.secondary)
                }
                // Tokens are opaque; Label(token) renders the real app name and icon.
                ForEach(Array(selection.applicationTokens.prefix(5)), id: \.self) { token in
                    Label(token).font(.footnote)
                }
                ForEach(Array(selection.categoryTokens.prefix(3)), id: \.self) { token in
                    Label(token).font(.footnote)
                }
            }
        }
    }
}
