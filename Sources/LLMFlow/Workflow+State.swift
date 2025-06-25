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

    public enum PipeStateType: Hashable, Sendable {
        case start
        case stream
        case running
        case end
    }

    public struct PipeState {
        let type: PipeStateType
        let node: any Node
        
        // Notice: get stream through stream property only
        let context: Context
        
        // Notice: `stream` can only be consumed once as it's orignal stream is from nio
        let stream: AnyAsyncSequence<Context.Value>?
    }
}

extension Workflow.PipeStateType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .start:
            "start"
        case .stream:
            "stream"
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
    public struct RunningState: AsyncSequence, Sendable {
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

extension Workflow.RunningState {
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        typealias Err = Workflow.PipeErr

        private let delegate: any WorkflowControl
        public var node: any Node
        public let executor: Executor

        private var postNode: (any Node)?
        private var preNode: (any Node)?

        public init(delegate: any WorkflowControl, executor: Executor, node: any Node, inputs: [String: FlowData]) {
            self.delegate = delegate
            self.postNode = node
            self.node = node
            self.executor = executor
        }

        public mutating func next() async throws -> Workflow.PipeState? {
            // Stop Iteration
            guard let node = self.postNode else { return nil }

            // Initial Setup
            self.preNode = self.node
            self.node = node
            self.postNode = nil

            // Perform Node Execution
            try await node.run(executor: executor)

            let context = executor.context

            // Test if the current can directly return and no necessary being blocked to collection stream data.
            let edges = delegate.edges(from: node.id)
            if let to = edges.first?.to, let next = delegate.node(id: to), next is EndNode {
                self.postNode = next
                // TODO: [2025/06/26 <Huanan>] Find a way to collectio the stream an update the context
                // TODO: [2025/06/26 <Huanan>] Reset output to .none
                let stream = context.output.withLock { $0 }.stream
                return Workflow.PipeState(type: .running, node: node, context: context, stream: stream)
            }

            // Reach Ending Node, Collection all the information to return.
            if node is EndNode {
                postNode = nil
                // TODO: [2025/06/25 <Huanan>] Add ending summary
                return Workflow.PipeState(type: .end, node: node, context: context, stream: nil)
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

            // Setup next node
            self.postNode = next

            let type: Workflow.PipeStateType = node is StartNode ? .start : .running
            return Workflow.PipeState(type: type, node: node, context: context, stream: nil)
        }

    }
}
