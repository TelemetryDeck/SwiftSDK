#if canImport(CryptoKit)
import CryptoKit
#endif
import CommonCrypto
import Foundation

/// A wrapper for crypto hash algorithms.
enum CryptoHashing {
    /// Returns a String representation of the SHA256 digest created with Apples CryptoKit library if available, else falls back to the ``commonCryptoSha256(strData:)`` function.
    /// [CryptoKit](https://developer.apple.com/documentation/cryptokit) is Apples modern, safe & performant crypto library that
    /// should be preferred where available.
    /// [CommonCrypto](https://github.com/apple-oss-distributions/CommonCrypto) provides compatibility with older OS versions,
    /// apps built with Xcode versions lower than 11 and non-Apple platforms like Linux.
    static func sha256(str: String) -> String {
        if let strData = str.data(using: String.Encoding.utf8) {
            #if canImport(CryptoKit)
                if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
                    let digest = SHA256.hash(data: strData)
                    return digest.compactMap { String(format: "%02x", $0) }.joined()
                } else {
                    // OS version requirement not met, but built with Xcode 11+ for Apple Platforms
                    return commonCryptoSha256(strData: strData)
                }
            #else
                // Linux, etc. (and iOS when compiled with < Xcode 11.)
                return commonCryptoSha256(strData: strData)
            #endif
        }
        return ""
    }

    /**
     * Example SHA 256 Hash using CommonCrypto
     * CC_SHA256 API exposed from from CommonCrypto-60118.50.1:
     * https://opensource.apple.com/source/CommonCrypto/CommonCrypto-60118.50.1/include/CommonDigest.h.auto.html
     **/
    static func commonCryptoSha256(strData: Data) -> String {
        /// #define CC_SHA256_DIGEST_LENGTH     32
        /// Creates an array of unsigned 8 bit integers that contains 32 zeros
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

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
            sha256String += String(format: "%02x", UInt8(byte))
        }

        return sha256String
    }
}
