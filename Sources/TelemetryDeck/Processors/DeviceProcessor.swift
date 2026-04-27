import Foundation

#if os(macOS)
    import IOKit
#endif

/// Enriches events with device model, OS version, architecture, timezone, and run context metadata.
public struct DeviceProcessor: EventProcessor {
    private let cachedParameters: EventParameters

    /// Creates a processor and caches device and environment information at init time.
    public init() {
        var parameters = EventParameters()

        let platform: String = {
            #if os(macOS)
                return "macOS"
            #elseif os(visionOS)
                return "visionOS"
            #elseif os(iOS)
                #if targetEnvironment(macCatalyst)
                    return "macCatalyst"
                #else
                    if #available(iOS 14.0, *), ProcessInfo.processInfo.isiOSAppOnMac {
                        return "isiOSAppOnMac"
                    } else {
                        return "iOS"
                    }
                #endif
            #elseif os(watchOS)
                return "watchOS"
            #elseif os(tvOS)
                return "tvOS"
            #else
                return "Unknown Platform"
            #endif
        }()
        parameters[DefaultParams.Device.platform] = platform

        let operatingSystem: String = {
            #if os(macOS)
                return "macOS"
            #elseif os(iOS)
                return "iOS"
            #elseif os(watchOS)
                return "watchOS"
            #elseif os(tvOS)
                return "tvOS"
            #elseif os(visionOS)
                return "visionOS"
            #else
                return "Unknown"
            #endif
        }()
        parameters[DefaultParams.Device.operatingSystem] = operatingSystem

        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        parameters[DefaultParams.Device.systemVersion] =
            "\(operatingSystem) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        parameters[DefaultParams.Device.systemMajorVersion] = "\(operatingSystem) \(osVersion.majorVersion)"
        parameters[DefaultParams.Device.systemMajorMinorVersion] = "\(operatingSystem) \(osVersion.majorVersion).\(osVersion.minorVersion)"

        let modelName = Self.getModelName()
        parameters[DefaultParams.Device.modelName] = modelName

        let architecture: String = {
            var systemInfo = utsname()
            uname(&systemInfo)
            let machineMirror = Mirror(reflecting: systemInfo.machine)
            return machineMirror.children.reduce("") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return identifier }
                return identifier + String(UnicodeScalar(UInt8(value)))
            }
        }()
        parameters[DefaultParams.Device.architecture] = architecture

        parameters[DefaultParams.Device.timeZone] = TimezoneFormatting.utcOffsetString()

        #if targetEnvironment(simulator)
            parameters[DefaultParams.RunContext.isSimulator] = "true"
        #else
            parameters[DefaultParams.RunContext.isSimulator] = "false"
        #endif

        #if DEBUG
            parameters[DefaultParams.RunContext.isDebug] = "true"
        #else
            parameters[DefaultParams.RunContext.isDebug] = "false"
        #endif

        let isTestFlight: Bool = {
            #if DEBUG
                return false
            #elseif targetEnvironment(simulator)
                return false
            #else
                guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else { return false }
                return appStoreReceiptURL.lastPathComponent == "sandboxReceipt" || appStoreReceiptURL.path.contains("sandboxReceipt")
            #endif
        }()
        parameters[DefaultParams.RunContext.isTestFlight] = isTestFlight ? "true" : "false"

        let isAppStore: Bool = {
            #if DEBUG
                return false
            #else
                #if targetEnvironment(simulator)
                    return false
                #else
                    return !isTestFlight
                #endif
            #endif
        }()
        parameters[DefaultParams.RunContext.isAppStore] = isAppStore ? "true" : "false"

        let targetEnvironment: String = {
            #if targetEnvironment(simulator)
                return "simulator"
            #elseif targetEnvironment(macCatalyst)
                return "macCatalyst"
            #else
                return "native"
            #endif
        }()
        parameters[DefaultParams.RunContext.targetEnvironment] = targetEnvironment

        self.cachedParameters = parameters
    }

    private static func getModelName() -> String {
        #if os(iOS)
            if #available(iOS 14.0, *) {
                if ProcessInfo.processInfo.isiOSAppOnMac {
                    var size = 0
                    sysctlbyname("hw.model", nil, &size, nil, 0)
                    var machine = [CChar](repeating: 0, count: size)
                    sysctlbyname("hw.model", &machine, &size, nil, 0)
                    return String(cString: machine)
                }
            }
        #endif
        #if os(macOS)
            if #available(macOS 11, *) {
                #if compiler(>=6.0)
                    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
                #else
                    let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
                #endif
                var modelIdentifier: String?
                if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data
                {
                    modelIdentifier = String(decoding: modelData.prefix(while: { $0 != 0 }), as: UTF8.self)
                }
                IOObjectRelease(service)
                if let modelIdentifier { return modelIdentifier }
            }
        #endif
        #if os(visionOS)
            #if targetEnvironment(simulator)
                if let simulatorModelIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
                    !simulatorModelIdentifier.isEmpty
                {
                    return simulatorModelIdentifier
                }
            #else
                var size = 0
                sysctlbyname("hw.machine", nil, &size, nil, 0)
                if size > 0 {
                    var machine = [CChar](repeating: 0, count: size)
                    sysctlbyname("hw.machine", &machine, &size, nil, 0)
                    let identifier = String(cString: machine)
                    if !identifier.isEmpty, identifier != "arm64", identifier != "x86_64" {
                        return identifier
                    }
                }
            #endif
        #endif
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /// Adds cached device metadata parameters to the context.
    public func process(
        _ input: EventInput,
        context: EventContext,
        next: @Sendable (EventInput, EventContext) async throws -> Event
    ) async throws -> Event {
        var context = context
        context.addParameters(cachedParameters)
        return try await next(input, context)
    }
}
