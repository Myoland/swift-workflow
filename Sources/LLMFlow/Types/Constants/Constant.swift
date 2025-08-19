//
//  Constant.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/27.
//

extension ContextStoreKey {
    public static let WorkflowRootKey: ContextStoreKey = "workflow"
    public static let WorkflowInputsKeyPath: ContextStoreKeyPath = [WorkflowRootKey, "inputs"]
    public static let WorkflowOutputKeyPath: ContextStoreKeyPath = [WorkflowRootKey, "output"]

    public static let WorkflowNodeRunResultKey: ContextStoreKey = "result"
}
