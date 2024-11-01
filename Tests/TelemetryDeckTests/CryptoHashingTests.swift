@testable import TelemetryDeck
import Testing
#if canImport(CryptoKit)
import CryptoKit
#endif

struct CryptoHashingTests {
    #if canImport(CryptoKit)
    @Test
    func cryptoKitAndCommonCryptoHaveSameDigestStringResults() {
        let stringToHash = "how do i get cowboy paint off a dog ."
        let dataToHash = stringToHash.data(using: .utf8)!

        let expectedDigestString = "5b8fab7cf45fcece0e99a05950611b7b355917e4fb6daa73fd3d7590764fa53b"

        #expect(expectedDigestString == CryptoHashing.sha256(string: stringToHash, salt: ""))
        #expect(expectedDigestString == CryptoHashing.commonCryptoSha256(strData: dataToHash))

        // even though we already test if we can import CryptoKit, somehow this still fails on iOS 12,
        // so we're gating it to iOS 13 et al.
        if #available(watchOS 7, iOS 13, macOS 10.14, tvOS 13, *) {
            // calling directly to prove that CryptoKit produces same reult, as ``sha256(str:)`` can fall back,
            #expect(expectedDigestString == SHA256.hash(data: dataToHash).compactMap { String(format: "%02x", $0) }.joined())
        }
    }

    @Test
    func saltedResultsAreDifferentFromUnsaltedResults() {
        let stringToHash = "how do i get cowboy paint off a dog ."
        let salt = "q8wMvgVW3LzGCRQiLSLk"
        let expectedDigestString = "d46208db801b09cf055fedd7ae0390e9797fc00d1bcdcb3589ea075ca157e0d6"

        let secondSalt = "x21MTSq3MRSmLjVFsYIe"
        let expectedSecondDigestString = "acb027bb031c0f73de26c6b8d0441d9c98449d582a538014c44ca49b4c299aa8"

        #expect(expectedDigestString == CryptoHashing.sha256(string: stringToHash, salt: salt))
        #expect(expectedSecondDigestString == CryptoHashing.sha256(string: stringToHash, salt: secondSalt))
        #expect(CryptoHashing.sha256(string: stringToHash, salt: salt) != CryptoHashing.sha256(string: stringToHash, salt: secondSalt))
    }
    #endif
}
