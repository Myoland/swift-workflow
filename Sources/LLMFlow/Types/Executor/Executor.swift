//
//  Executor.swift
//  swift-workflow
//
//  Created by Huanan on 2025/7/25.
//

import LazyKit
import SynchronizationKit
import Logging

/// A class responsible for executing the logic of a ``RunnableNode``.
///
/// The `Executor` provides a node with the necessary context and resources to perform its task.
/// It holds a reference to the shared ``Context`` for the workflow run, a ``ServiceLocator`` for
/// dependency injection, and a `Logger`.
///
/// An `Executor` instance is created by the ``Workflow/RunningUpdates/Iterator`` and passed to the
/// `run(executor:)` method of each ``RunnableNode``.
public final class Executor: Sendable {
    /// The service locator for resolving dependencies.
    public let locator: ServiceLocator?
    private let lockedContext: LazyLockedValue<Context>
    /// The logger for recording execution events.
    public let logger: Logger

    /// A decoder for handling `Any` types.
    public let anyDecoder = AnyDecoder()
    /// An encoder for handling `Any` types.
    public let anyEncoder = AnyEncoder()

    /// Initializes a new `Executor`.
    ///
    /// - Parameters:
    ///   - locator: An optional service locator.
    ///   - context: The shared context for the workflow run.
    ///   - logger: An optional logger.
    public init(
        locator: ServiceLocator? = nil,
        context: Context = Context(),
        logger: Logger? = nil
    ) {
        self.locator = locator
        self.lockedContext = .init(context)
        self.logger = logger ?? Logger.Internal
    }
}

extension Executor {
    /// Provides thread-safe access to the execution ``Context``.
    var context: Context {
        get {
            self.lockedContext.withLock { $0 }
        }
    }
}
