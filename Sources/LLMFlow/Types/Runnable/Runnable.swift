//
//  Runnable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//

public protocol Runnable: Sendable {
    func run(executor: Executor) async throws -> NodeOutput?

    func wait(_ context: Context) async throws -> Context.Value?

    func update(_ context: Context, value: Context.Value) throws
}

public extension Runnable {
    func wait(_ context: Context) async throws -> Context.Value? {
        let output = context.payload.withLock { $0 }
        return output?.value
    }
}
