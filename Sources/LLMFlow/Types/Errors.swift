//
//  Workflow+Error.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

public enum RuntimeError: Error {
    case StartNodeNotFound
    case CanNotMatchAnEdge
    case NextNodeNotFound
}

public enum ConstructError: Error {
    case missingStartNode
    case typeMissMatchStartNode
}

