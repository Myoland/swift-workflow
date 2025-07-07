//
//  Workflow+State.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/14.
//

import LazyKit



// MARK: Workflow + Run

extension Workflow {
    
    public func run0(inputs: [String: FlowData]) throws -> RunningUpdates {
        try RunningUpdates(workflow: self, startNode: self.requireStartNode(), inputs: inputs)
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
        case running
        case end
    }

    public struct PipeState {
        let type: PipeStateType
        let node: any Node

        // Notice: get stream through stream property only
        let context: Context
        
        let value: Context.Value?
    }
}

extension Workflow.PipeStateType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .start:
            "start"
        case .generating:
            "generating"
        case .running:
            "running"
        case .end:
            "end"
        }
    }
}

extension Workflow.PipeState {
    var output: NodeOutput {
        context.output.withLock { $0 }
    }
}


extension Workflow {
    public struct RunningUpdates: AsyncSequence, Sendable {
        let workflow: Workflow
        let startNode: StartNode
        let inputs: [String: FlowData]

        public func makeAsyncIterator() -> Iterator {
            Iterator(delegate: workflow,
                     executor: Executor(locator: workflow.locator, context: .init(output: .block(inputs)), logger: workflow.logger),
                     node: startNode,
                     inputs: inputs)
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
        case generating(current: any Node, next: any Node, AnyAsyncSequence<Context.Value>.AsyncIterator)
        case end
    }
    
    
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = Workflow.PipeErr

        private let delegate: any WorkflowControl
        public let executor: Executor
        
        public let state: LazyLockedValue<RunningState>

        public init(delegate: any WorkflowControl, executor: Executor, node: StartNode, inputs: [String: FlowData]) {
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
                return Workflow.PipeState(type: .end, node: node, context: context, value: nil)
                
            case .running(current: let node, previous: _):
                try await node.run(executor: executor)
                
                let edges = delegate.edges(from: node.id)
                
                if let to = edges.first?.to,
                   let next = delegate.node(id: to),
                   next is EndNode,
                   let stream = context.output.withLock({ $0 }).stream
                {
                    let iterator = stream.makeAsyncIterator()
                    self.state.withLock { $0 = .generating(current: node, next: next, iterator) }
                    return Workflow.PipeState(type: .running, node: node, context: context, value: nil)
                }
                
                // Block the node stream if needed and match a edge by condition.
                let variable = try await node.wait(context)
                context.output.withLock { $0 = .none }

                if let variable {
                    try node.update(context, value: variable)
                    executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: variable))")
                }

                let edge = edges.first { $0.condition?.eval(context.filter(keys: nil)) ?? true }

                guard let edge else { throw Err.notMatchEdge }

                guard let next = delegate.node(id: edge.to) else { throw Err.nodeNotFound }
                
                self.state.withLock { $0 = .running(current: next, previous: node) }
                return Workflow.PipeState(type: .running, node: node, context: context, value: nil)
            case .generating(let node, let next, var iterator):
                if let elem = try await iterator.next() {
                    self.state.withLock { $0 = .generating(current: node, next: next, iterator) }
                    return Workflow.PipeState(type: .generating, node: node, context: context, value: elem)
                } else {
                    self.state.withLock { $0 = .running(current: next, previous: nil) }
                    return Workflow.PipeState(type: .running, node: node, context: context, value: nil)
                }
            case .modifying:
                preconditionFailure("unreachable")
            }
        }
    }
}
