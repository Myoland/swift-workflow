//
//  Node.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

import AsyncAlgorithms
import Foundation
import LazyKit

// MARK: Node + Output

public enum NodeOutput: Sendable {
    case block(Context.Value?)
    case stream(AnyAsyncSequence<Context.Value>)
}

extension NodeOutput {
    var value: Context.Value? {
        guard case .block(let value) = self else { return nil }
        return value
    }

    var stream: AnyAsyncSequence<Context.Value>? {
        guard case .stream(let stream) = self else { return nil }
        return stream
    }
}

// MARK: Node

public protocol Node: Sendable, Hashable, Codable {
    typealias ID = String

    var id: ID { get }
    var type: NodeType { get }
}

public extension Node {
    var resultKeyPaths: ContextStoreKeyPath { [id, ContextStoreKey.WorkflowNodeRunOutputKey] }
}

public extension Node {
    func getResult(_ context: Context) -> AnySendable {
        context[path: resultKeyPaths]
    }
}

// MAKR: Node + Save

protocol ResultResaveableNode: Node {
    var output: ID? { get }
}

extension ResultResaveableNode {
    public var outputKeyPaths: ContextStoreKeyPath? {
        guard let output else { return nil }
        return ContextStoreKey.WorkflowOutputKeyPath + [output]
    }
}

extension ResultResaveableNode {
    public func getOutput(_ context: Context) -> AnySendable {
        context[path: outputKeyPaths]
    }
}
