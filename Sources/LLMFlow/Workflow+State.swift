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

    public func matchEdge(id: Node.ID, context: Context) -> Edge? {
        let edges = flows[id]
        return edges?.first {
            $0.condition?.eval(context.filter(keys: nil)) ?? true
        }
    }

    func reachEnd(id: Node.ID) -> Bool {
        guard let edges = flows[id], edges.count == 1, let toID = edges.first?.to else {
            return false
        }

        guard let to = nodes[toID], to.type == .END else {
            return false
        }

        return true
    }
}


extension Workflow {
    public typealias PipeUpdates = AnyAsyncSequence<PipeState>

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

protocol WorkflowControl: Sendable {
    func reachEnd(id: Node.ID) -> Bool
    func edges(from id: Node.ID) -> [Workflow.Edge]
    func node(id: Node.ID) -> (any Node)?
}

extension Workflow: WorkflowControl {
    func edges(from id: Node.ID) -> [Workflow.Edge] {
        flows[id] ?? []
    }

    func node(id: String) -> (any Node)? {
        self.nodes[id]
    }
}

extension Workflow.RunningState {
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = Workflow.PipeErr

        let delegate: any WorkflowControl
        var node: any Node
        let executor: Executor

        private var reachEnd: Bool

        init(delegate: any WorkflowControl, locator: StoreLocator, node: any Node, inputs: [String: FlowData]) {
            self.delegate = delegate
            self.node = node
            self.executor = .init(locator: locator, context: .init(pipe: .block(inputs)))
            self.reachEnd = false
        }

        public mutating func next() async throws -> Workflow.PipeState? {

            guard !reachEnd else { return nil }

            try await node.run(executor: executor)

            let edges = delegate.edges(from: node.id)
            if let to = edges.first?.to, let nextNode = delegate.node(id: to), nextNode is EndNode {
                node = nextNode
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
            }

            let edge = edges.first {
                $0.condition?.eval(context.filter(keys: nil)) ?? true
            }

            guard let edge else {
                throw Err.notMatchEdge
            }

            guard let nextNode = delegate.node(id: edge.to) else {
                // match a edge but the next not found.
                throw Err.nodeNotFound
            }
            
            if node is StartNode {
                node = nextNode
                return .start
            }
            
            node = nextNode

            return .running
        }

    }
}
