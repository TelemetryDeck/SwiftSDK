import Foundation

enum Environment {
    static let isAppExtension: Bool = {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }()
}
