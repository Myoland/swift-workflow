//
//  Constant.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/27.
//

extension DataKeyPath {
    public static let WorkflowRootKey: DataKeyPath = "workflow"
    public static let WorkflowInputsKeyPath: DataKeyPaths = [WorkflowRootKey, "inputs"]

    public static let WorkflowNodeRunResultKey: DataKeyPath = "result"
}
