import Foundation
import Testing

@testable import TelemetryDeck

#if os(iOS) || os(tvOS) || os(visionOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct AccessibilityProcessorTests {
    #if os(iOS) || os(tvOS) || os(visionOS)
        @Test
        func leftToRightDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .leftToRight) == "leftToRight")
        }

        @Test
        func rightToLeftDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .rightToLeft) == "rightToLeft")
        }
    #elseif os(macOS)
        @Test
        func leftToRightDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .leftToRight) == "leftToRight")
        }

        @Test
        func rightToLeftDirectionString() {
            #expect(AccessibilityProcessor.directionString(from: .rightToLeft) == "rightToLeft")
        }
    #endif
}
