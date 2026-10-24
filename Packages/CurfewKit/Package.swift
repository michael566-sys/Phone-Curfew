// swift-tools-version: 5.10
import PackageDescription

// CurfewCore: pure Foundation logic (time rules, unlock state machine, email rules).
//             Builds on macOS too, so `swift test` runs without a device.
// CurfewKit:  everything that touches the Screen Time frameworks or the App Group.
//             Re-exports CurfewCore, so targets only `import CurfewKit`.
let package = Package(
    name: "CurfewKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CurfewKit", targets: ["CurfewKit"]),
    ],
    targets: [
        .target(name: "CurfewCore"),
        .target(name: "CurfewKit", dependencies: ["CurfewCore"]),
        .testTarget(name: "CurfewCoreTests", dependencies: ["CurfewCore"]),
    ]
)
