import CurfewKit
import DeviceActivity
import SwiftUI

/// Hosts the report extension. Usage numbers are drawn by the extension; the app never sees them.
struct StatsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case day = "Day", week = "Week", month = "Month"
        var id: Self { self }
    }

    @Environment(AppModel.self) private var model
    @State private var period: Period = .day

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                blockedAttempts

                DeviceActivityReport(context, filter: filter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Stats")
        }
    }

    private var blockedAttempts: some View {
        let days = period == .day ? 1 : period == .week ? 7 : 30
        let store = SharedStore.shared
        return HStack {
            Label("Blocked attempts", systemImage: "hand.raised.fill")
            Spacer()
            Text("\(store.shieldHits(.view, lastDays: days, clock: model.clock))")
                .font(.headline)
        }
        .padding(.horizontal)
    }

    private var context: DeviceActivityReport.Context {
        switch period {
        case .day: .day
        case .week: .week
        case .month: .month
        }
    }

    private var filter: DeviceActivityFilter {
        let calendar = model.clock.calendar
        let now = Date()
        let today = calendar.startOfDay(for: now)
        switch period {
        case .day:
            return DeviceActivityFilter(
                segment: .hourly(during: DateInterval(start: today, end: now)),
                users: .all,
                devices: .init([.iPhone])
            )
        case .week, .month:
            let days = period == .week ? 6 : 29
            let start = calendar.date(byAdding: .day, value: -days, to: today) ?? today
            return DeviceActivityFilter(
                segment: .daily(during: DateInterval(start: start, end: now)),
                users: .all,
                devices: .init([.iPhone])
            )
        }
    }
}
