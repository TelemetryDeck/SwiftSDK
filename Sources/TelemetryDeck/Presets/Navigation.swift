import Foundation
import SwiftUI

private actor NavigationState {
    var previousPath: String?

    func setPreviousPath(_ path: String) {
        previousPath = path
    }
}

private let navigationState = NavigationState()

extension TelemetryDeck {
    /// Sends a navigation event recording a transition from `source` to `destination`.
    public static func navigationPathChanged(
        from source: String,
        to destination: String,
        customUserID: String? = nil
    ) async {
        await navigationState.setPreviousPath(destination)

        let params: EventParameters = [
            DefaultParams.Navigation.schemaVersion.rawValue: "1",
            DefaultParams.Navigation.identifier.rawValue: "\(source) -> \(destination)",
            DefaultParams.Navigation.sourcePath.rawValue: source,
            DefaultParams.Navigation.destinationPath.rawValue: destination,
        ]
        await sdkEvent(DefaultEvents.Navigation.pathChanged, parameters: params, customUserID: customUserID)
    }

    /// Sends a navigation event to `destination`, using the last recorded path as the source.
    public static func navigationPathChanged(
        to destination: String,
        customUserID: String? = nil
    ) async {
        let source = await navigationState.previousPath ?? ""
        await navigationPathChanged(from: source, to: destination, customUserID: customUserID)
    }
}

@available(iOS 14, macCatalyst 14, *)
extension View {
    @ViewBuilder
    fileprivate func _onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

@available(iOS 14, macCatalyst 14, *)
extension View {
    /// Automatically sends a navigation event when the view appears and whenever `path` changes.
    public func trackNavigation(path: String) -> some View {
        self
            .onAppear {
                Task {
                    await TelemetryDeck.navigationPathChanged(to: path)
                }
            }
            ._onChangeCompat(of: path) { newPath in
                Task {
                    await TelemetryDeck.navigationPathChanged(to: newPath)
                }
            }
    }
}
