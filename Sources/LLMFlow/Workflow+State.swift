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
    
    public func run(context: inout Context, pipe: OutputPipe) async throws -> OutputPipe {
        let startNode = try requireStartNode()
        
        var pipe: OutputPipe = pipe
        var node: any Node = startNode
        
        while true {
            
            pipe = try await node.run(context: context, pipe: pipe)
            
            if reachEnd(id: node.id) {
                break
            }
            
            if let variable = try await node.wait(pipe) {
                try node.update(&context, value: variable)
                pipe = .none
            }
            
            guard let edge = matchEdge(id: node.id, context: context),
                  let nextNode = self.nodes[edge.to]
            else {
                break
            }
            
            node = nextNode
        }
        
        return pipe
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
        case stream(OutputPipe)
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
            Iterator(delegate: workflow, pipe: .block(inputs), node: startNode)
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
        var context: Context
        var node: any Node
        
        private var reachEnd: Bool
        
        init(delegate: any WorkflowControl, context: Context = .init(), pipe: OutputPipe, node: any Node) {
            self.delegate = delegate
            self.context = context
            self.context.pipe = pipe
            self.node = node
            self.reachEnd = false
        }
        
        public mutating func next() async throws -> Workflow.PipeState? {
            
            guard !reachEnd else { return nil }
            
            context.pipe = try await node.run(context: context, pipe: context.pipe)
            
            let edges = delegate.edges(from: node.id)
            if let to = edges.first?.to, let nextNode = delegate.node(id: to), node is EndNode {
                if node is LLMNode {
                    node = nextNode
                    return .stream(context.pipe)
                }
            }
            
            if node is EndNode {
                reachEnd = true
                return .end
            }
            
            if node is StartNode {
                return .start
            }
            
            let variable = try await node.wait(context.pipe)
            context.pipe = .none
            
            if let variable {
                try node.update(&context, value: variable)
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
            
            node = nextNode
            
            return .running
        }
        
    }
}
