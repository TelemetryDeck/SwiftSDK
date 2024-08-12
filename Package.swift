// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TelemetryClient",
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
            dependencies: ["TelemetryClient"],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "TelemetryClient",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "TelemetryClientTests",
            dependencies: ["TelemetryClient"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        )
    ]
)
