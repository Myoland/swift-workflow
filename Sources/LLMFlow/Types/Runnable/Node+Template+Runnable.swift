//
//  Node+Template+Runnable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//

import Tracing

extension TemplateNode: Runnable {
    public func run(executor: Executor) async throws -> NodeOutput? {
        return try await withSpan("TemplateNode Run \(id)", context: executor.serviceContext) { span in
            span.attributes.set("node_id", value: .string(id))

            let context = executor.context
            let result = try template.render(context.filter(keys: nil))
            return .block(result)
        }
    }

    public func update(_ context: Context, value: Context.Value) throws {
        context[path: resultKeyPaths] = value
    }
}
