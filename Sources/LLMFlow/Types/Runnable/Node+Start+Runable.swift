//
//  Node+Start+Runable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//


extension StartNode: Runnable {
    typealias Err = PayloadVerifyErr
    
    public func run(executor: Executor) async throws -> NodeOutput? {
        let payload = executor.context.payload.withLock({ $0 })
        
        guard let value = payload?.value as? [Context.Key: FlowData] else {
            return .none
        }
        
        executor.logger.debug("[*] Start Node. Values: \(value)")
        
        try verify(data: value)
        
        executor.logger.info("[*] Start Node. Verify Success.")
        return .block(value.asAny)
    }
    
    public func update(_ context: Context, value: Context.Value) throws {
        context[path: ContextStoreKey.WorkflowInputsKeyPath] = value
    }
    
    public func verify(
        data: [ContextStoreKey: FlowData]
    ) throws {
        try Self.verify(data: data, decls: self.inputs)
    }
    
    public static func verify(
        data: [ContextStoreKey: FlowData],
        decls: [ContextStoreKey: FlowData.TypeDecl]
    ) throws {
        for (key, decl) in decls {
            guard let data = data[key] else {
                throw Err.inputDataNotFound(key: key)
            }
            
            guard data.decl == decl else {
                throw Err.inputDataTypeMissMatch(key: key, expect: decl, actual: data)
            }
        }
    }
}
