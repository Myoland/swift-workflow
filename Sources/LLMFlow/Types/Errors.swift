//
//  Workflow+Error.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

public enum RuntimeError: Error {
    case unknow(message: String)
    case StartNodeNotFound
    case CanNotMatchAnEdge
    case NextNodeNotFound
    
    case locatorNotFound
    case serviceNotFound(name: String)
}

public enum ConstructError: Error {
    case missingStartNode
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
