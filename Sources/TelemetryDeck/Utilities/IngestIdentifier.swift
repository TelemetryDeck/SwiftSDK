import Foundation

enum IngestIdentifier {
    static func isValid(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy(isAllowed)
    }

    static func sanitized(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.map { isAllowed($0) ? $0 : "_" }))
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "A"..."Z", "a"..."z", "0"..."9", ".", "_", "-":
            true
        default:
            false
        }
    }
}
