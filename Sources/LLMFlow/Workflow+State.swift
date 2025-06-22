//
//  Workflow+State.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/14.
//

import LazyKit



// MARK: Workflow + Run

extension Workflow {

    public func run0(inputs: [String: FlowData]) throws -> RunningState {
        try RunningState(workflow: self, startNode: self.requireStartNode(), inputs: inputs)
    }
}


extension Workflow {

    public enum PipeErr: Error {
        case nodeNotFound
        case notMatchEdge
    }

    public enum PipeState: Sendable {
        case start
        case stream(AnyAsyncSequence<Context.Value>)
        case running
        case end
    }
}

extension Workflow {
    public struct RunningState: AsyncSequence, Sendable {
        let workflow: Workflow
        let startNode: StartNode
        let inputs: [String: FlowData]

        public func makeAsyncIterator() -> Iterator {
            Iterator(delegate: workflow, locator: workflow.locator, node: startNode, inputs: inputs)
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

extension Workflow.RunningState {
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = Workflow.PipeErr

        private let delegate: any WorkflowControl
        public var node: any Node
        public let executor: Executor

        private var reachEnd: Bool

        public init(delegate: any WorkflowControl, locator: ServiceLocator, node: any Node, inputs: [String: FlowData]) {
            self.delegate = delegate
            self.node = node
            self.executor = .init(locator: locator, context: .init(pipe: .block(inputs)))
            self.reachEnd = false
        }

        public mutating func next() async throws -> Workflow.PipeState? {
            let node = self.node

            guard !reachEnd else { return nil }

            try await node.run(executor: executor)

            let edges = delegate.edges(from: node.id)
            if let to = edges.first?.to, let next = delegate.node(id: to), next is EndNode {
                self.node = next
                if case let .stream(stream) = executor.context.pipe.withLock({ $0 }){
                    return .stream(stream)
                } else {
                    return .running
                }
            }

            if node is EndNode {
                reachEnd = true
                return .end
            }

            let context = executor.context
            let variable = try await node.wait(context)
            context.pipe.withLock { $0 = .none }

            if let variable {
                try node.update(context, value: variable)
                executor.logger.info("[*] Node(\(node.id)). Update Success. Value: \(String(describing: variable))")
            }

            let edge = edges.first {
                $0.condition?.eval(context.filter(keys: nil)) ?? true
            }

            guard let edge else {
                throw Err.notMatchEdge
            }

            guard let next = delegate.node(id: edge.to) else {
                // match a edge but the next not found.
                throw Err.nodeNotFound
            }

            self.node = next

            if node is StartNode {
                return .start
            } else {
                return .running
            }
        }

    }
}
