// swift-tools-version:5.9
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
        .library(name: "TelemetryDeck", targets: ["TelemetryClient"]),  // new name
        .library(name: "TelemetryClient", targets: ["TelemetryClient"]),  // old name
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TelemetryClient",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "TelemetryClientTests",
            dependencies: ["TelemetryClient"]
        )
    ]
)
