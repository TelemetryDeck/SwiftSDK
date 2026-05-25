// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TelemetryDeck",
    platforms: [
        .macOS(.v12),
        .macCatalyst(.v13),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "TelemetryDeck", targets: ["TelemetryDeck"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TelemetryDeck",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .defaultIsolation(nil),
            ]
        ),
        .testTarget(
            name: "TelemetryDeckTests",
            dependencies: ["TelemetryDeck"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .defaultIsolation(nil),
            ]
        ),
        .testTarget(
            name: "TelemetryDeckApproachableConcurrencyTests",
            dependencies: ["TelemetryDeck"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .defaultIsolation(nil),
            ]
        ),
    ]
)
