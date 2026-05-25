import Foundation

/// Chains a sequence of `EventProcessor` instances and a finalizer to produce a transmittable `Event`.
public struct ProcessorPipeline: Sendable {
    private let processors: [any EventProcessor]
    private let finalizer: EventFinalizer
    private let logger: any Logging

    /// Creates a pipeline with the given processors and finalizer.
    public init(processors: [any EventProcessor], finalizer: EventFinalizer, logger: any Logging = DefaultLogger()) {
        self.processors = processors
        self.finalizer = finalizer
        self.logger = logger
    }

    /// Runs the input through the processor chain and returns the finalised event.
    public func process(_ input: EventInput, context: EventContext) async throws -> Event {
        try await runChain(input: input, context: context, index: 0)
    }

    private func runChain(input: EventInput, context: EventContext, index: Int) async throws -> Event {
        guard index < processors.count else {
            return finalizer.finalize(input, context: context)
        }
        logger.log(.debug, "\(String(describing: type(of: processors[index]))) handling event '\(input.name)'")
        return try await processors[index].process(input, context: context) { @Sendable inp, ctx in
            try await runChain(input: inp, context: ctx, index: index + 1)
        }
    }
}
