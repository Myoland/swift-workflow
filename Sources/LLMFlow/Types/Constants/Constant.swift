//
//  Constant.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/27.
//


extension DataKeyPath {
    static let WorkflowRootKey: DataKeyPath = "workflow"
    static let WorkflowInputsKeyPath: DataKeyPaths = [WorkflowRootKey, "inputs"]
    
    static let WorkflowNodeRunResultKey: DataKeyPath = "result"
}
