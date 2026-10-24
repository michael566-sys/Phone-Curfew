import FamilyControls
import SwiftUI
import UIKit

@main
struct PhoneCurfewApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { model.onLaunch() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() }
                }
                // Wall-clock rules follow the phone: restart schedules when the zone or clock changes.
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                    model.handleClockChange()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    model.handleClockChange()
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.authorization == .approved {
            TabView {
                TonightView().tabItem { Label("Tonight", systemImage: "moon.stars") }
                StatsView().tabItem { Label("Stats", systemImage: "chart.bar") }
                SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
            }
        } else {
            OnboardingView()
        }
    }
}
