//
//  Node+Template+Runnable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//



extension TemplateNode: Runnable {
    
    public func run(executor: Executor) async throws -> NodeOutput? {
        let context = executor.context
        
        let result = try template.render(context.filter(keys: nil))
        return .block(result)
    }
    
    func update(_ context: Context, value: Context.Value) throws {
        context[path: resultKeyPaths] = value
    }
}
