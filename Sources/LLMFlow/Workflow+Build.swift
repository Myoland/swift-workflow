//
//  Workflow+Build.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

import Algorithms

extension Workflow {

    public init?(config: Workflow.Config, locator: ServiceLocator) throws {
        try config.validate()

        let startNode = try config.requireStartNode()

        let nodes: [String: any Node] = config.nodes.keyed { $0.id }
        let flows: [Node.ID: Edges] = config.edges.grouped { $0.from }

        self.init(nodes: nodes, flows: flows, startNodeID: startNode.id, locator: locator)
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
