//
//  Workflow+Build.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//


extension Workflow {
    public static func buildWorkflow(config: Workflow.Config) throws -> Workflow {
        try config.validate()
        
        let startNode = try config.requireStartNode()
        
        return .init(nodes: [:], flows: [:], startNodeID: startNode.id)
    }
}

extension Workflow.Config {
    
    public func findNodes(of type: NodeType) -> [any Node] {
        return nodes.filter { $0.type == type }
    }
    
    func requireStartNode() throws -> StartNode {
        let startNodes = findNodes(of: .START)
        guard startNodes.count == 1 else {
            throw Err.missingStartNode
        }
        
        guard let startNode = startNodes.first as? StartNode else {
            throw Err.typeMissMatchStartNode
        }
        
        return startNode
    }
    
    func validate() throws {
        try checkDAG()
        try checkUnusedNodes()
        try checkEndToStartPath()
    }
    
    // DAG check. if there is a cycle in the graph.
    func checkDAG() throws {
        
    }
    
    // unused nodes check
    func checkUnusedNodes() throws {
        
    }
    
    // end to start path check
    func checkEndToStartPath() throws {
        
    }
    
}
