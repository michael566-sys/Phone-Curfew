@_exported import CurfewCore
import Foundation

/// The App Group every target shares. Each target's Info.plist carries it as
/// `CurfewAppGroupID`, filled from the APP_GROUP_ID build setting.
public enum AppGroup {
    public static let identifier: String =
        Bundle.main.object(forInfoDictionaryKey: "CurfewAppGroupID") as? String
        ?? "group.com.songyuanzhang.phonecurfew"
}

#if os(iOS)
import DeviceActivity
import ManagedSettings
import SwiftUI // DeviceActivityReport is a SwiftUI view

public extension ManagedSettingsStore.Name {
    static let bedtime = Self("bedtime")
    static let daytime = Self("daytime")
    static let strict = Self("strict")
}

public extension DeviceActivityName {
    static let bedtime = Self("bedtime")
    static let daytime = Self("daytime")
    static let unlockWindow = Self("unlockWindow")
}

public extension DeviceActivityReport.Context {
    static let day = Self("day")
    static let week = Self("week")
    static let month = Self("month")
}
#endif
