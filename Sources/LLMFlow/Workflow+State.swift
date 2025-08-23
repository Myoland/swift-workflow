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
        context.payload.withLock { $0 = .block(inputs) }
        return try RunningUpdates(workflow: self, startNode: self.requireStartNode(), inputs: inputs, context: context)
    }
}


extension Workflow {
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
    public var payload: NodeOutput? {
        context.payload.withLock { $0 }
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
    func node(id: Node.ID) -> (any RunnableNode)?
}

extension Workflow: WorkflowControl {
    public func edges(from id: Node.ID) -> [Workflow.Edge] {
        flows[id] ?? []
    }

    public func node(id: String) -> (any RunnableNode)? {
        self.nodes[id]
    }
}

public typealias RunnableNode = Runnable & Node

extension Workflow.RunningUpdates {
    public enum RunningState: Sendable {
        case initial(StartNode)
        case modifying
        case running(current: any RunnableNode, previous: (any RunnableNode)?)
        case generating(current: any RunnableNode, AnyAsyncSequence<Context.Value>.AsyncIterator)
        case end
        
        var isModifying: Bool {
            guard case .modifying = self else {
                return false
            }
            return true
        }
        
        var isEnd: Bool {
            guard case .end = self else {
                return false
            }
            return true
        }
    }
}

extension Workflow.RunningUpdates {
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = RuntimeError

        private let delegate: any WorkflowControl
        public let executor: Executor

        private let lockedState: LazyLockedValue<RunningState>

        public init(delegate: any WorkflowControl, executor: Executor, node: StartNode) {
            self.delegate = delegate
            self.executor = executor
            self.lockedState = .init(.initial(node))
        }

        public mutating func next() async throws -> Workflow.PipeState? {
            let state: RunningState = self.lockedState.withLock { state in
                let old = state
                switch state {
                case .end:
                    break
                default:
                    state = .modifying
                }
                return old
            }
            assert(state.isModifying == false) // Make sure next() is not re-enter.
            
            let cxtRef = executor.context
            switch state {
            case .end:
                return nil

            case .initial(let node):
                self.state = .running(current: node, previous: nil)
                return Workflow.PipeState(type: .start, node: node, context: cxtRef, value: nil)

            case .running(current: let node, previous: _) where node is EndNode:
                self.state = .end
                return Workflow.PipeState(type: .end, node: node, context: cxtRef, value: "TODO: Object Used for summrize")

            case .running(current: let node, previous: _):
                let output = try await node.run(executor: executor)
                cxtRef.payload.withLock { $0 = output }

                if let stream = output?.stream {
                    let iterator = stream.makeAsyncIterator()
                    self.state = .generating(current: node, iterator)
                    return Workflow.PipeState(type: .startGenerating, node: node, context: cxtRef, value: nil)
                }

                if let value = output?.value {
                    try node.update(cxtRef, value: value)
                    executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: value))")
                }

                let next = try requireNextNode(from: node.id, context: cxtRef.filter(keys: nil))

                self.state = .running(current: next, previous: node)
                return Workflow.PipeState(type: .running, node: node, context: cxtRef, value: nil)

            case .generating(let node, var iterator):
                if let elem = try await iterator.next() {
                    self.state = .generating(current: node, iterator)
                    return Workflow.PipeState(type: .generating, node: node, context: cxtRef, value: elem)
                }

                // iterator finished
                let value = try await node.wait(cxtRef)
                try node.update(cxtRef, value: value)
                executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: value))")

                let next = try requireNextNode(from: node.id, context: cxtRef.filter(keys: nil))

                self.state = .running(current: next, previous: node)
                return Workflow.PipeState(type: .finishGenerating, node: node, context: cxtRef, value: nil)

            case .modifying:
                unreachable()
            }
        }

        public func requireNextNode(from nodeID: Node.ID, context: [Context.Key: Context.Value]) throws -> any RunnableNode {
            let edges = delegate.edges(from: nodeID)
            let edge = edges.first { $0.condition?.eval(context) ?? true }

            guard let edge else { throw Err.CanNotMatchAnEdge }
            guard let next = delegate.node(id: edge.to) else { throw Err.NextNodeNotFound }

            return next
        }
    }
}


extension Workflow.RunningUpdates.Iterator {
    var state: Workflow.RunningUpdates.RunningState {
        get {
            self.lockedState.withLock { $0 }
        }
        set {
            self.lockedState.withLock { $0 = newValue }
        }
    }
}
