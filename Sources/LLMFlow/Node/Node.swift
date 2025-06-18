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

    func run(context: Context, pipe: OutputPipe) async throws -> OutputPipe
    
    func wait(_ pipe: OutputPipe) async throws -> Context.Value?
    
    func update(_ context: inout Context, value: Context.Value) throws
}

extension Node {

    // force convert the pipe to blocked value
    // please check if it should be blocked.
    public func wait(_ pipe: OutputPipe) async throws -> Context.Value? {
        if case .none = pipe {
            return nil
        }
        
        if case let .block(value) = pipe {
            return value
        }

        guard case .stream(let stream) = pipe else {
            return nil
        }

        todo("Throw error. stream should wait on its self.")
    }
    
    public func update(_ context: inout Context, value: Context.Value) throws {
        let encoder = AnyEncoder()
        if let result = try encoder.encode(value) {
            // context[path: id, DataKeyPath.NodeRunResultKey] = result
        }
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
