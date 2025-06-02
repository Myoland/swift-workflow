//
//  Workflow+Error.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

extension Workflow {
    enum Err: Error {
        case StartNodeNotFound
        case CanNotMatchAnEdge
        case NextNodeNotFound
    }
}

extension Workflow.Config {
    enum Err: Error {
        case missingStartNode
        case typeMissMatchStartNode
    }
}

