import CurfewKit
import DeviceActivity
import ExtensionKit
import SwiftUI

/// Usage data stays inside this extension's sandbox; it can only be drawn, not exported.
@main
struct CurfewReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        UsageReportScene(context: .day, period: .day) { UsageReportView(summary: $0) }
        UsageReportScene(context: .week, period: .week) { UsageReportView(summary: $0) }
        UsageReportScene(context: .month, period: .month) { UsageReportView(summary: $0) }
    }
}

enum ReportPeriod {
    case day, week, month
}

struct UsageSummary {
    struct Bucket: Identifiable {
        var start: Date
        var duration: TimeInterval
        var id: Date { start }
    }

    struct AppUsage: Identifiable {
        var name: String
        var duration: TimeInterval
        var id: String { name }
    }

    var period: ReportPeriod
    var buckets: [Bucket] = []
    var topApps: [AppUsage] = []
    var pickups = 0

    var total: TimeInterval { buckets.reduce(0) { $0 + $1.duration } }
}

struct UsageReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let period: ReportPeriod
    let content: (UsageSummary) -> UsageReportView

    init(context: DeviceActivityReport.Context, period: ReportPeriod, content: @escaping (UsageSummary) -> UsageReportView) {
        self.context = context
        self.period = period
        self.content = content
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageSummary {
        var bucketTotals: [Date: TimeInterval] = [:]
        var appTotals: [String: TimeInterval] = [:]
        var pickups = 0

        for await device in data {
            for await segment in device.activitySegments {
                bucketTotals[segment.dateInterval.start, default: 0] += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName
                            ?? app.application.bundleIdentifier
                            ?? "Unknown app"
                        appTotals[name, default: 0] += app.totalActivityDuration
                        pickups += app.numberOfPickups
                    }
                }
            }
        }

        var summary = UsageSummary(period: period)
        summary.buckets = bucketTotals
            .map { UsageSummary.Bucket(start: $0.key, duration: $0.value) }
            .sorted { $0.start < $1.start }
        summary.topApps = appTotals
            .map { UsageSummary.AppUsage(name: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
            .prefix(5)
            .map { $0 }
        summary.pickups = pickups
        return summary
    }
}
