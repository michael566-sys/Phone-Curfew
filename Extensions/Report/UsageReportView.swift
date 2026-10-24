import Charts
import SwiftUI

struct UsageReportView: View {
    let summary: UsageSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                totals
                chart
                if summary.period == .month { weeklyAverages }
                topApps
            }
            .padding()
        }
    }

    private var totals: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(totalLabel).font(.subheadline).foregroundStyle(.secondary)
                Text(format(summary.period == .day ? summary.total : dailyAverage))
                    .font(.largeTitle.bold())
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Pickups").font(.subheadline).foregroundStyle(.secondary)
                Text("\(summary.pickups)").font(.title2.bold())
            }
        }
    }

    private var chart: some View {
        Chart(summary.buckets) { bucket in
            BarMark(
                x: .value("Time", bucket.start, unit: summary.period == .day ? .hour : .day),
                y: .value("Minutes", bucket.duration / 60)
            )
            .foregroundStyle(.indigo)
        }
        .chartYAxisLabel("min")
        .frame(height: 180)
    }

    private var weeklyAverages: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly averages").font(.headline)
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, avg in
                HStack {
                    Text("Week \(index + 1)")
                    Spacer()
                    Text("\(format(avg)) / day").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var topApps: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top apps").font(.headline)
            if summary.topApps.isEmpty {
                Text("No usage yet.").foregroundStyle(.secondary)
            }
            ForEach(summary.topApps) { app in
                HStack {
                    Text(app.name)
                    Spacer()
                    Text(format(app.duration)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Helpers

    private var totalLabel: String {
        summary.period == .day ? "Today" : "Daily average"
    }

    private var dailyAverage: TimeInterval {
        summary.buckets.isEmpty ? 0 : summary.total / Double(summary.buckets.count)
    }

    /// Average per day for each run of 7 daily buckets, oldest first.
    private var weeks: [TimeInterval] {
        stride(from: 0, to: summary.buckets.count, by: 7).map { start in
            let slice = summary.buckets[start..<min(start + 7, summary.buckets.count)]
            return slice.reduce(0) { $0 + $1.duration } / Double(slice.count)
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
