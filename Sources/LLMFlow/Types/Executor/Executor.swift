//
//  Executor.swift
//  swift-workflow
//
//  Created by Huanan on 2025/7/25.
//

import LazyKit
import SynchronizationKit
import OSLog

public final class Executor: Sendable {
    public let locator: ServiceLocator?
    private let lockedContext: LazyLockedValue<Context>
    public let logger: Logger

    public let anyDecoder = AnyDecoder()
    public let anyEncoder = AnyEncoder()

    public init(
        locator: ServiceLocator? = nil,
        context: Context = Context(),
        logger: Logger? = nil
    ) {
        self.locator = locator
        self.lockedContext = .init(context)
        self.logger = logger ?? .init(subsystem: .Log.subsystem, category: .Log.Category.executor)
    }
}

extension Executor {
    var context: Context {
        get {
            self.lockedContext.withLock { $0 }
        }
    }
}
