//
//  Node.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

import LazyKit
import AsyncAlgorithms
import Foundation


public enum OutputPipe: Sendable {
    case none
    case block(Context.Value)
    case stream(AnyAsyncSequence<Context.Value>)
}

public protocol Node: Sendable, Hashable, Codable {
    typealias ID = String

    var id: ID { get }
    var type: NodeType { get }

    func run(executor: Executor) async throws

    func wait(_ context: Context) async throws -> Context.Value?

    func update(_ context: Context, value: Context.Value) throws
    
    static var resultKey: String { get }
}

extension Node {
    public static var resultKey: String { DataKeyPath.NodeRunResultKey }
    
    // force convert the pipe to blocked value
    // please check if it should be blocked.
    public func wait(_ context: Context) async throws -> Context.Value? {
        let pipe = context.pipe.withLock { $0 }

        return switch pipe {
        case .none:
            nil
        case let .block(value):
            value
        case .stream:
            nil
        }
    }

    public func updateIntoResult(_ context: Context, value: Context.Value) throws {
        context[path: id, DataKeyPath.NodeRunResultKey] = value
    }
}

public typealias NodeVariableKey = Context.Key

public enum NodeType: String, Sendable {
    case START
    case END
    case TEMPLATE
    case LLM
}

extension NodeType: Codable {}
