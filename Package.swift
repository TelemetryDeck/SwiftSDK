// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TelemetryDeck",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v12),
        .watchOS(.v5),
        .tvOS(.v13),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "TelemetryDeck", targets: ["TelemetryDeck"]),  // new name
        .library(name: "TelemetryClient", targets: ["TelemetryClient"]),  // old name
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TelemetryDeck",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "TelemetryClient",
            dependencies: ["TelemetryDeck"],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "TelemetryDeckTests",
            dependencies: ["TelemetryDeck"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        )
    ]
)
