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
        case stream(Context, AnyAsyncSequence<Context.Value>)
        case running(Context)
        case end
    }
}

extension Workflow.PipeState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .start:
            "start"
        case .stream(_, _):
            "stream"
        case .running(_):
            "running"
        case .end:
            "end"
        }
    }
}

extension Workflow {
    public struct RunningState: AsyncSequence, Sendable {
        let workflow: Workflow
        let startNode: StartNode
        let inputs: [String: FlowData]

        public func makeAsyncIterator() -> Iterator {
            Iterator(delegate: workflow,
                     executor: Executor(locator: workflow.locator, context: .init(pipe: .block(inputs)), logger: workflow.logger),
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

extension Workflow.RunningState {
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = Workflow.PipeErr

        private let delegate: any WorkflowControl
        public var node: any Node
        public let executor: Executor

        private var reachEnd: Bool
        private var postNode: (any Node)?
        private var preNode: (any Node)?

        public init(delegate: any WorkflowControl, executor: Executor, node: any Node, inputs: [String: FlowData]) {
            self.delegate = delegate
            self.postNode = node
            self.node = node
            self.executor = executor
            self.reachEnd = false
        }

        public mutating func next() async throws -> Workflow.PipeState? {
            guard !reachEnd, let node = self.postNode else { return nil }
            
            self.preNode = self.node
            self.node = node
            self.postNode = nil

            try await node.run(executor: executor)
            
            let context = executor.context
            
            let edges = delegate.edges(from: node.id)
            if let to = edges.first?.to, let next = delegate.node(id: to), next is EndNode {
                self.postNode = next
                if case let .stream(stream) = executor.context.pipe.withLock({ $0 }){
                    return .stream(context, stream)
                } else {
                    return .running(context)
                }
            }

            if node is EndNode {
                reachEnd = true
                postNode = nil
                return .end
            }

            // let context = executor.context
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

            self.postNode = next

            if node is StartNode {
                return .start
            } else {
                return .running(context)
            }
        }

    }
}
