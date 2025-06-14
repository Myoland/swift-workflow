import Foundation
import os.log
import LazyKit


// MARK: Workflow + Edge

extension Workflow {
    typealias Edges = [Edge]
    
    public struct Edge : Sendable {
        public let from: Node.ID
        public let to: Node.ID
        public let condition: Condition?
    }
}

extension Workflow.Edge: Codable {}
extension Workflow.Edge: Hashable {}

// MARK: Workflow

public struct Workflow : Sendable{
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
