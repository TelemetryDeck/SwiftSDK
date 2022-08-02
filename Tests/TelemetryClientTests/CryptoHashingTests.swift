@testable import TelemetryClient
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif

final class CryptoHashingTests: XCTestCase {
    #if canImport(CryptoKit)
    func testCryptoKitAndCommonCryptoHaveSameDigestStringResults() {
        let stringToHash = "how do i get cowboy paint off a dog ."
        let dataToHash = stringToHash.data(using: .utf8)!

        let expectedDigestString = "5b8fab7cf45fcece0e99a05950611b7b355917e4fb6daa73fd3d7590764fa53b"

        XCTAssertEqual(expectedDigestString, CryptoHashing.sha256(str: stringToHash, salt: ""))
        XCTAssertEqual(expectedDigestString, CryptoHashing.commonCryptoSha256(strData: dataToHash))

        // calling directly to prove that CryptoKit produces same reult, as ``sha256(str:)`` can fall back,
        // even if it shouldn't fallback here because we're inside a `canImport(CryptoKit)` check
        XCTAssertEqual(expectedDigestString, SHA256.hash(data: dataToHash).compactMap { String(format: "%02x", $0) }.joined())
    }
    
    func testSaltedResultsAreDifferentFromUnsaltedResults() {
        let stringToHash = "how do i get cowboy paint off a dog ."
        let salt = "q8wMvgVW3LzGCRQiLSLk"
        let expectedDigestString = "d46208db801b09cf055fedd7ae0390e9797fc00d1bcdcb3589ea075ca157e0d6"
        
        let secondSalt = "x21MTSq3MRSmLjVFsYIe"
        let expectedSecondDigestString = "acb027bb031c0f73de26c6b8d0441d9c98449d582a538014c44ca49b4c299aa8"
        
        XCTAssertEqual(expectedDigestString, CryptoHashing.sha256(str: stringToHash, salt: salt))
        XCTAssertEqual(expectedSecondDigestString, CryptoHashing.sha256(str: stringToHash, salt: secondSalt))
        XCTAssertNotEqual(CryptoHashing.sha256(str: stringToHash, salt: salt), CryptoHashing.sha256(str: stringToHash, salt: secondSalt))
    }
    #endif
}
