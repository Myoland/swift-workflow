//
//  Node+End+Runable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//

extension EndNode: Runnable {
    /// The run implementation for `EndNode`.
    ///
    /// An `EndNode` does not perform any action and returns `nil`, signaling the end of a workflow path.
    public func run(executor: Executor) async throws -> NodeOutput? { nil }

    /// The update implementation for `EndNode`.
    ///
    /// This method does nothing as the `EndNode` does not process any output.
    public func update(_ context: Context, value: Context.Value) throws {}
}
