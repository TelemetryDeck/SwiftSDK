import Foundation

/// Minimal abstraction over the URLSession method used to dispatch event batches.
public protocol HTTPDataLoader: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoader {}
