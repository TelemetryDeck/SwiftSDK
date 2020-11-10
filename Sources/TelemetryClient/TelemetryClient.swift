//
//  Telemetry
//
//  Created by Daniel Jilg on 27.11.19.
//  Copyright © 2019 breakthesystem. All rights reserved.
//

import Foundation
import CommonCrypto

#if os(iOS)
import UIKit
#endif

public typealias TelemetrySignalType = String
public struct TelemetryManagerConfiguration {
    public let telemetryAppID: String
    public let telemetryServerBaseURL: URL
    
    public init(appID: String, baseURL: URL? = nil) {
        self.telemetryAppID = appID
        
        if let baseURL = baseURL {
            self.telemetryServerBaseURL = baseURL
        } else {
            self.telemetryServerBaseURL = URL(string: "https://apptelemetry.io")!
        }
    }
}

public class TelemetryManager {
    public static func initialize(with configuration: TelemetryManagerConfiguration) {
        initializedTelemetryManager = TelemetryManager(configuration: configuration)
    }
    
    public static func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        TelemetryManager.shared.send(signalType, for: clientUser, with: additionalPayload)
    }
    
    public static var shared: TelemetryManager {
        guard let telemetryManager = initializedTelemetryManager else {
            fatalError("Please call TelemetryManager.initialize(...) before accessing the shared telemetryManager instance.")
        }
        
        return telemetryManager
    }
    
    public func send(_ signalType: TelemetrySignalType, for clientUser: String? = nil, with additionalPayload: [String: String] = [:]) {
        // Do not send telemetry in DEBUG mode
        #if DEBUG
        return
        #else
        
        // Do not send telemetry from simulator
        guard !isSimulator else { return }

        DispatchQueue.global().async { [self] in
            let path = "/api/v1/apps/\(configuration.telemetryAppID)/signals/"
            let url = configuration.telemetryServerBaseURL.appendingPathComponent(path)

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let payLoad: [String: String] = [
                "platform": platform,
                "systemVersion": systemVersion,
                "appVersion": appVersion,
                "buildNumber": buildNumber,
                "isSimulator": "\(isSimulator)",
                "isTestFlight": "\(isTestFlight)",
                "isAppStore": "\(isAppStore)",
                "modelName": "\(modelName)",
            ].merging(additionalPayload, uniquingKeysWith: { (_, last) in last })
            
            let signalPostBody: SignalPostBody = SignalPostBody(type: "\(signalType)", clientUser: sha256(str: clientUser ?? defaultUserIdentifier), payload: payLoad)

            urlRequest.httpBody = try! JSONEncoder().encode(signalPostBody)

            let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
                if let error = error { print(error, data as Any, response as Any) }
                if let data = data, let dataAsUTF8 = String(data: data, encoding: .utf8) {
                    print(dataAsUTF8)
                }
            }
            task.resume()
        }
        #endif
    }
    
    private init(configuration: TelemetryManagerConfiguration) {
        self.configuration = configuration
    }
    
    private static var initializedTelemetryManager: TelemetryManager?
    
    private let configuration: TelemetryManagerConfiguration
    
    private struct SignalPostBody: Codable {
        let type: String
        let clientUser: String
        let payload: Dictionary<String, String>?
    }

}

private extension TelemetryManager {
    var isSimulatorOrTestFlight: Bool {
        return (isSimulator || isTestFlight)
    }

    var isSimulator: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return (path.contains("CoreSimulator") || path.contains("XCTestDevices"))
    }

    var isTestFlight: Bool {
        guard let path = Bundle.main.appStoreReceiptURL?.path else {
            return false
        }
        return path.contains("sandboxReceipt")
    }

    var isAppStore: Bool {
        return !isSimulatorOrTestFlight
    }
    
    var systemVersion: String {
        #if os(macOS)
        return "\(platform) \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.patchVersion)"
        #elseif os(iOS)
        return "\(platform)  \(UIDevice.current.systemVersion)"
        #elseif os(watchOS)
        return "\(platform) \(UIDevice.current.systemVersion)"
        #elseif os(tvOS)
        return "\(platform) \(UIDevice.current.systemVersion)"
        #else
        return "\(platform)"
        #endif
    }
    
    var platform: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #else
        return "Unknown Platform"
        #endif
    }

    var appVersion: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return appVersion ?? "0"
    }

    var buildNumber: String {
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return buildNumber ?? "0"
    }
    
    var defaultUserIdentifier: String {
        #if os(macOS)
        return "unknown user \(systemVersion) \(buildNumber)"
        #else
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown user \(systemVersion) \(buildNumber)"
        #endif
    }
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

private extension TelemetryManager {
    /**
     * Example SHA 256 Hash using CommonCrypto
     * CC_SHA256 API exposed from from CommonCrypto-60118.50.1:
     * https://opensource.apple.com/source/CommonCrypto/CommonCrypto-60118.50.1/include/CommonDigest.h.auto.html
     **/
    func sha256(str: String) -> String {
     
        if let strData = str.data(using: String.Encoding.utf8) {
            /// #define CC_SHA256_DIGEST_LENGTH     32
            /// Creates an array of unsigned 8 bit integers that contains 32 zeros
            var digest = [UInt8](repeating: 0, count:Int(CC_SHA256_DIGEST_LENGTH))
     
            /// CC_SHA256 performs digest calculation and places the result in the caller-supplied buffer for digest (md)
            /// Takes the strData referenced value (const unsigned char *d) and hashes it into a reference to the digest parameter.
            _ = strData.withUnsafeBytes {
                // CommonCrypto
                // extern unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md)  -|
                // OpenSSL                                                                             |
                // unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md)        <-|
                CC_SHA256($0.baseAddress, UInt32(strData.count), &digest)
            }
     
            var sha256String = ""
            /// Unpack each byte in the digest array and add them to the sha256String
            for byte in digest {
                sha256String += String(format:"%02x", UInt8(byte))
            }

            return sha256String
        }
        return ""
    }
}
