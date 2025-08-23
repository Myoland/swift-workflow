//
//  Workflow+State.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/14.
//

import LazyKit
import SynchronizationKit


// MARK: Workflow + Run

extension Workflow {
    public func run(inputs: [String: FlowData], context: Context = .init()) throws -> RunningUpdates {
        context.output.withLock { $0 = .block(inputs) }
        return try RunningUpdates(workflow: self, startNode: self.requireStartNode(), inputs: inputs, context: context)
    }
}


extension Workflow {

    public enum PipeErr: Error {
        case nodeNotFound
        case notMatchEdge
    }

    public enum PipeStateType: Hashable, Sendable {
        case start
        case generating
        case startGenerating
        case finishGenerating
        case running
        case end
    }

    public struct PipeState {
        public let type: PipeStateType
        public let node: any Node

        public let context: Context

        /// Available when type equal to ``Workflow/PipeStateType/generating``
        public let value: Context.Value?
    }
}

extension Workflow.PipeStateType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .start:
            "start"
        case .generating:
            "generating"
        case .startGenerating:
            "generating"
        case .finishGenerating:
            "finishGenerating"
        case .running:
            "running"
        case .end:
            "end"
        }
    }
}

extension Workflow.PipeState {
    public var output: NodeOutput {
        context.output.withLock { $0 }
    }
}


extension Workflow {
    public struct RunningUpdates: AsyncSequence, Sendable {
        public let workflow: Workflow
        public let startNode: StartNode
        public let inputs: [String: FlowData]
        public let context: Context

        public func makeAsyncIterator() -> Iterator {
            Iterator(delegate: workflow,
                     executor: Executor(locator: workflow.locator, context: context, logger: workflow.logger),
                     node: startNode)
        }
    }
}

public protocol WorkflowControl: Sendable {
    func edges(from id: Node.ID) -> [Workflow.Edge]
    func node(id: Node.ID) -> (any Node)?
}

extension Workflow: WorkflowControl {
    public func edges(from id: Node.ID) -> [Workflow.Edge] {
        flows[id] ?? []
    }

    public func node(id: String) -> (any Node)? {
        self.nodes[id]
    }
}

extension Workflow.RunningUpdates {
    public enum RunningState {
        case initial(StartNode)
        case modifying
        case running(current: any Node, previous: (any Node)?)
        case generating(current: any Node, AnyAsyncSequence<Context.Value>.AsyncIterator)
        case end
    }


    public struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = Workflow.PipeErr

        private let delegate: any WorkflowControl
        public let executor: Executor

        public let state: LazyLockedValue<RunningState>

        public init(delegate: any WorkflowControl, executor: Executor, node: StartNode) {
            self.delegate = delegate
            self.executor = executor
            self.state = .init(.initial(node))
        }

        public mutating func next() async throws -> Workflow.PipeState? {
            // prepare state and lock it if nessary
            let state: RunningState = self.state.withLock { state in
                let old = state
                switch state {
                case .initial(let node):
                    state = .running(current: node, previous: node)
                case .running(current: _, previous: _):
                    state = .modifying
                case .modifying:
                    preconditionFailure("unreachable")
                default:
                    break
                }
                return old
            }

            let context = executor.context
            switch state {
            case .end:
                return nil
            case .initial(let node):
                return Workflow.PipeState(type: .start, node: node, context: context, value: nil)
            default:
                break
            }

            switch state {
            case .end, .initial(_):
                preconditionFailure("unreachable")

            case .running(current: let node, previous: _) where node is EndNode:
                // summarize
                self.state.withLock { $0 = .end }
                return Workflow.PipeState(type: .end, node: node, context: context, value: "TODO: Object Used for summrize")

            case .running(current: let node, previous: _):
                try await node.run(executor: executor)

                let output = context.output.withLock { $0 }

                switch output {
                case .none:
                    break
                case .stream(let stream):
                    let iterator = stream.makeAsyncIterator()
                    self.state.withLock { $0 = .generating(current: node, iterator) }
                    return Workflow.PipeState(type: .startGenerating, node: node, context: context, value: nil)
                case .block(let value):
                    try node.update(context, value: value)
                    executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: value))")
                }

                let next = try requireNextNode(from: node.id, context: context.filter(keys: nil))

                self.state.withLock { $0 = .running(current: next, previous: node) }
                return Workflow.PipeState(type: .running, node: node, context: context, value: nil)

            case .generating(let node, var iterator):
                if let elem = try await iterator.next() {
                    let iter = iterator
                    self.state.withLock { $0 = .generating(current: node, iter) }
                    return Workflow.PipeState(type: .generating, node: node, context: context, value: elem)
                }

                // iterator finished
                let value = try await node.wait(context)
                try node.update(context, value: value)
                executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: value))")

                let next = try requireNextNode(from: node.id, context: context.filter(keys: nil))

                self.state.withLock { $0 = .running(current: next, previous: nil) }
                return Workflow.PipeState(type: .finishGenerating, node: node, context: context, value: nil)
            case .modifying:
                preconditionFailure("unreachable")
            }
        }

        public func requireNextNode(from nodeID: Node.ID, context: [Context.Key: Context.Value]) throws -> any Node {
            let edges = delegate.edges(from: nodeID)
            let edge = edges.first { $0.condition?.eval(context) ?? true }

            guard let edge else { throw Err.notMatchEdge }
            guard let next = delegate.node(id: edge.to) else { throw Err.nodeNotFound }

            return next
        }
    }
}
