import CommonCrypto
import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#endif

enum CryptoHashing {
    static func sha256(string: String, salt: String) -> String {
        if let strData = (string + salt).data(using: String.Encoding.utf8) {
            #if canImport(CryptoKit)
                if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
                    let digest = SHA256.hash(data: strData)
                    return digest.compactMap { String(format: "%02x", $0) }.joined()
                } else {
                    return commonCryptoSha256(strData: strData)
                }
            #else
                return commonCryptoSha256(strData: strData)
            #endif
        }
        return ""
    }

    static func commonCryptoSha256(strData: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = strData.withUnsafeBytes {
            CC_SHA256($0.baseAddress, UInt32(strData.count), &digest)
        }
        var sha256String = ""
        for byte in digest {
            sha256String += String(format: "%02x", UInt8(byte))
        }
        return sha256String
    }
}
