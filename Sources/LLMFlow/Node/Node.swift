//
//  Node.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

import LazyKit
import AsyncAlgorithms
import Foundation

// MARK: Node + Output

public enum NodeOutput: Sendable {
    case none
    case block(Context.Value?)
    case stream(AnyAsyncSequence<Context.Value>)
}

extension NodeOutput {
    var stream: AnyAsyncSequence<Context.Value>? {
        guard case let .stream(stream) = self else { return nil }
        return stream
    }
}

// MARK: Node

public protocol Node: Sendable, Hashable, Codable {
    typealias ID = String

    var id: ID { get }
    var type: NodeType { get }

    func run(executor: Executor) async throws

    func wait(_ context: Context) async throws -> Context.Value?

    func update(_ context: Context, value: Context.Value) throws
}

// MARK: Node + Default

extension Node {

    // force convert the pipe to blocked value
    // please check if it should be blocked.
    public func wait(_ context: Context) async throws -> Context.Value? {
        let pipe = context.output.withLock { $0 }

        return switch pipe {
        case .none:
            nil
        case let .block(value):
            value
        case .stream:
            nil
        }
    }

    public var resultKeyPaths: ContextStoreKeyPath { [id, ContextStoreKey.WorkflowNodeRunResultKey] }

    public func updateIntoResult(_ context: Context, path: ContextStoreKeyPath, value: Context.Value) throws {
        context[path: path] = value
    }

    public func updateIntoResult(_ context: Context, value: Context.Value) throws {
        try updateIntoResult(context, path: resultKeyPaths, value: value)
    }
}

// MAKR: Node + Save

protocol ResultResaveableNode: Node {
    var output: ID? { get }

    func resave(_ context: Context, value: Context.Value) throws
}

extension ResultResaveableNode {
    public var outputKeyPaths: ContextStoreKeyPath? {
        guard let output else { return nil }
        return ContextStoreKey.WorkflowOutputKeyPath + [output]
    }

    func resave(_ context: Context, value: Context.Value) throws {
        guard let key = outputKeyPaths else { return }
        try updateIntoResult(context, path: key, value: value)
    }
}

// MARK: Node + Type

public struct NodeType: RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension NodeType {
    static let START = NodeType(rawValue: "START")
    static let END = NodeType(rawValue: "END")
    static let TEMPLATE = NodeType(rawValue: "TEMPLATE")
    static let LLM = NodeType(rawValue: "LLM")
}

extension NodeType: Codable {}
extension NodeType: Hashable {}
