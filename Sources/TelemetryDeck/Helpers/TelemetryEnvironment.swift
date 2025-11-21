import Foundation

/// Represents the current telemetry execution environment.
internal enum TelemetryEnvironment {
    
    /// Indicates whether the code is running inside an app extension.
    ///
    /// Determined by checking whether the main bundle’s path ends with the `.appex` suffix.
    static let isAppExtension: Bool = {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }()
}
