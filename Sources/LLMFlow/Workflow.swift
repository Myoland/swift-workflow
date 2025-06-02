import Foundation
import os.log
import LazyKit


// MARK: Workflow + Edge

extension Workflow {
    typealias Edges = [Edge]
    
    public struct Edge {
        public let from: Node.ID
        public let to: Node.ID
        public let condition: Condition?
    }
}

extension Workflow.Edge: Codable {}
extension Workflow.Edge: Hashable {}

// MARK: Workflow

public struct Workflow {
    public typealias VariableKey = NodeVariableKey
    public typealias VariableValue = Context.Value

    let nodes: [Node.ID: any Node]
    let flows: [Node.ID: Edges]
    
    let startNodeID: Node.ID
}

extension Workflow {
    
    public func requireStartNode() throws -> StartNode  {
        guard let node = nodes[startNodeID] as? StartNode else {
            throw Err.StartNodeNotFound
        }
        return node
    }
    
}

// MARK: Workflow + Run

extension Workflow {
    
    public func run(context: inout Context, pipe: OutputPipe) async throws -> OutputPipe {
        
        let startNode = try requireStartNode()
        
        var pipe: OutputPipe = pipe
        var node: any Node = startNode
        
        while true {
            
            pipe = try await node.run(context: context, pipe: pipe)
            
            guard let edge = matchEdge(id: node.id, context: context),
                  let nextNode = self.nodes[edge.to]
            else {
                break
            }
            
            if let variable = try await node.wait(pipe) {
                try node.update(&context, value: variable)
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
}
