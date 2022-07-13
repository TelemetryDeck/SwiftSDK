@testable import TelemetryClient
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif

final class CryptoHashingTests: XCTestCase {
   #if canImport(CryptoKit)
   func testCryptoKitAndCommonCryptoHaveSameDigestStringResults() {
      let stringToHash = "I ... can't be a wizard. I'm just Harry – just Harry!"
      let dataToHash = stringToHash.data(using: .utf8)!

      let expectedDigestString = "a83adf48122e22cf86cd139b846a5b3fa486982d3bb13413a6f46efa078edfa5"

      XCTAssertEqual(expectedDigestString, CryptoHashing.sha256(str: stringToHash))
      XCTAssertEqual(expectedDigestString, CryptoHashing.commonCryptoSha256(strData: dataToHash))

      // calling directly to prove that CryptoKit produces same reult, as ``sha256(str:)`` can fall back,
      // even if it shouldn't fallback here because we're inside a `canImport(CryptoKit)` check
      XCTAssertEqual(expectedDigestString, SHA256.hash(data: dataToHash).compactMap { String(format: "%02x", $0) }.joined())
   }
   #endif
}
