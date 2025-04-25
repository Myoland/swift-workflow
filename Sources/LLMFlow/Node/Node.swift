//
//  Node.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

import AsyncAlgorithms
import Foundation

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct AnyAsyncSequence<Element>: Sendable, AsyncSequence {
    public typealias AsyncIteratorNextCallback = () async throws -> Element?

    public struct AsyncIterator: AsyncIteratorProtocol {
        let nextCallback: AsyncIteratorNextCallback

        init(nextCallback: @escaping AsyncIteratorNextCallback) {
            self.nextCallback = nextCallback
        }

        public mutating func next() async throws -> Element? {
            try await self.nextCallback()
        }
    }

    @usableFromInline
    var makeAsyncIteratorCallback: @Sendable () -> AsyncIteratorNextCallback

    public init<SequenceOfElement>(
        _ asyncSequence: SequenceOfElement
    ) where SequenceOfElement: AsyncSequence & Sendable, SequenceOfElement.Element == Element {
        self.makeAsyncIteratorCallback = {
            var iterator = asyncSequence.makeAsyncIterator()
            return {
                try await iterator.next()
            }
        }
    }

    public init(
        _ asyncSequenceMaker: @Sendable @escaping () -> AsyncIteratorNextCallback
    ) {
        self.makeAsyncIteratorCallback = asyncSequenceMaker
    }

    public func makeAsyncIterator() -> AsyncIterator {
        .init(nextCallback: self.makeAsyncIteratorCallback())
    }
}


public enum OutputPipe {
    case none
    case block(key: Context.Key, value: Context.Value)
    case stream(AnyAsyncSequence<Data>)
}

public protocol Node: Sendable, Hashable, Codable {
    typealias ID = String

    var id: ID { get }
    var type: NodeType { get }

    func run(context: inout Context) async throws -> OutputPipe
}

extension Node {
    public func run(context: inout Context) async throws -> OutputPipe {
        .none
    }

    // force convert the pipe to blocked value
    // please check if it should be blocked.
    public func convert(_ pipe: OutputPipe) async throws -> Context.Variable? {
        if case .none = pipe {
            return nil
        }

        if case let .block(key, value) = pipe {
            return (key: key, value: value)
        }

        guard case .stream(let stream) = pipe else {
            return nil
        }

        // NOTICE: THE FOLLOWING CODE IS JUST FOR EXAMPLE.
        // IMPLEMENT IT IN NODE ITSELF.

        // TODO: Maybe allow config the max size of the buffer
        let buffer = try await stream.collect(upTo: 1024 * 1024, using: .init())
        let string = String(buffer: buffer)
        return (key: "TODO", value: .single(.string(string)))
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
