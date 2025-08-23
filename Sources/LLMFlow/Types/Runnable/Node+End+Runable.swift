//
//  Node+End+Runable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//

extension EndNode: Runnable {
    func run(executor: Executor) async throws -> NodeOutput? { nil }
    
    func update(_ context: Context, value: Context.Value) throws {}
}
