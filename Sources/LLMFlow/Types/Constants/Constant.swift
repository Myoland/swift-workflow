//
//  Constant.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/27.
//

public extension ContextStoreKey {
    /// The root key under which all workflow-related data is stored in the ``Context``.
    static let WorkflowRootKey: ContextStoreKey = "workflow"

    /// The key path to the dictionary of initial inputs provided to the workflow.
    static let WorkflowInputsKeyPath: ContextStoreKeyPath = [WorkflowRootKey, "inputs"]
    /// The key path where nodes can write their final outputs to be collected.
    static let WorkflowOutputKeyPath: ContextStoreKeyPath = [WorkflowRootKey, "output"]

    /// The key used within a node's input dictionary to store its primary input.
    static let WorkflowNodeRunInputsKey: ContextStoreKey = "inputs"

    /// The key used within a node's result dictionary to store its primary output.
    static let WorkflowNodeRunOutputKey: ContextStoreKey = "output"
}
