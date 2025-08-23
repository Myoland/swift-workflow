//
//  Workflow+Error.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

/// Errors that can occur during the execution of a ``Workflow``.
public enum RuntimeError: Error {
    /// An unknown or unexpected error.
    case unknow(message: String)
    /// The designated ``StartNode`` could not be found in the workflow's node list.
    case StartNodeNotFound
    /// No outgoing `Edge` from the current node met its ``Condition``, halting the workflow.
    case CanNotMatchAnEdge
    /// The node specified by a matched `Edge` could not be found.
    case NextNodeNotFound
    /// The ``ServiceLocator`` was not available when a node required it.
    case locatorNotFound
    /// A required service could not be found in the ``ServiceLocator``.
    case serviceNotFound(name: String)
}

/// Errors that can occur during the construction of a ``Workflow`` from a ``Workflow/Config``.
public enum ConstructError: Error {
    /// The workflow configuration must contain exactly one ``StartNode``, but none or more than one was found.
    case missingStartNode
    /// A node designated as the start node was not of the `StartNode` type.
    case typeMissMatchStartNode
}

enum PayloadVerifyErr: Error, Hashable {
    case inputDataNotFound(key: String)
    case inputDataTypeMissMatch(key: String, expect: FlowData.TypeDecl, actual: FlowData?)
    case other(String)
}

extension PayloadVerifyErr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .inputDataNotFound(let key):
            return "Key Not Found For Key: '\(key)'."
        case .inputDataTypeMissMatch(let key, let expect, let actual):
            return "Data Type Miss Match For Key: '\(key)'. Expected: \(expect), Actual: \(actual ?? "nil")"
        case .other(let message):
            return "Unknown Error: \(message)."
        }
    }
}
