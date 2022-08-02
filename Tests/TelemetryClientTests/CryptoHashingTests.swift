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

      XCTAssertEqual(expectedDigestString, CryptoHashing.sha256(str: stringToHash))
      XCTAssertEqual(expectedDigestString, CryptoHashing.commonCryptoSha256(strData: dataToHash))

      // calling directly to prove that CryptoKit produces same reult, as ``sha256(str:)`` can fall back,
      // even if it shouldn't fallback here because we're inside a `canImport(CryptoKit)` check
      XCTAssertEqual(expectedDigestString, SHA256.hash(data: dataToHash).compactMap { String(format: "%02x", $0) }.joined())
   }
   #endif
}
