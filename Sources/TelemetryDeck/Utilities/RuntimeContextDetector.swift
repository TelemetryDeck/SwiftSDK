import Foundation

// Based on https://gist.github.com/lukaskubanek/cbfcab29c0c93e0e9e0a16ab09586996

public final class RuntimeContextDetector {
    public init() {}

    func isTestFlightContext() -> Bool {
        #if os(macOS) || targetEnvironment(macCatalyst)
            var staticCode: SecStaticCode?
            var status = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &staticCode)
            guard status == errSecSuccess, let staticCode else {
                return false
            }

            var requirement: SecRequirement?
            status = SecRequirementCreateWithString(
                "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.25.1]" as CFString,
                [],  // default
                &requirement
            )
            guard status == errSecSuccess else {
                return false
            }
            guard let requirement else {
                return false
            }
            status = SecStaticCodeCheckValidity(staticCode, [], requirement)
            return status == errSecSuccess
        #elseif os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
            guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else { return false }
            return appStoreReceiptURL.lastPathComponent == "sandboxReceipt" || appStoreReceiptURL.path.contains("sandboxReceipt")
        #else
            false
        #endif
    }
}
