//
//  Workflow+Build.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

import Algorithms
import Logging

extension Workflow {

    /// Initializes a ``Workflow`` from a configuration object.
    ///
    /// This initializer provides a convenient way to construct a workflow from a ``Workflow/Config``,
    /// which is often decoded from a file (e.g., YAML or JSON). It validates the configuration,
    /// extracts the nodes and edges, and constructs the `Workflow` instance.
    ///
    /// - Parameters:
    ///   - config: The ``Workflow/Config`` object describing the workflow's structure.
    ///   - locator: A service locator for dependency resolution.
    ///   - logger: An optional logger.
    /// - Throws: An error if the configuration is invalid (e.g., no start node, contains cycles).
    public init(config: Workflow.Config, locator: ServiceLocator, logger: Logger? = nil) throws {
        try config.validate()

        let startNode = try config.requireStartNode()

        let nodes: [String: any RunnableNode] = config.nodes.keyed { $0.id }
        let flows: [Node.ID: Edges] = config.edges.grouped { $0.from }

        self.init(nodes: nodes, flows: flows, startNodeID: startNode.id, locator: locator, logger: logger)
    }
}

extension Workflow.Config {

    /// Finds all nodes of a specific type within the configuration.
    ///
    /// - Parameter type: The ``NodeType`` to search for.
    /// - Returns: An array of nodes matching the specified type.
    public func findNodes(of type: NodeType) -> [any Node] {
        return nodes.filter { $0.type == type }
    }

    /// Retrieves the single ``StartNode`` from the configuration.
    ///
    /// - Throws: ``ConstructError/missingStartNode`` if zero or more than one start node is found.
    /// - Throws: ``ConstructError/typeMissMatchStartNode`` if the found start node is not of the `StartNode` type.
    /// - Returns: The ``StartNode`` instance.
    func requireStartNode() throws -> StartNode {
        let startNodes = findNodes(of: .START)
        guard startNodes.count == 1 else {
            throw ConstructError.missingStartNode
        }

        guard let startNode = startNodes.first as? StartNode else {
            throw ConstructError.typeMissMatchStartNode
        }

        return startNode
    }

    /// Validates the integrity of the workflow configuration.
    ///
    /// This method performs several checks to ensure the workflow is well-formed:
    /// - Verifies that the graph is a Directed Acyclic Graph (DAG), i.e., it contains no cycles.
    /// - Checks for any nodes that are defined but not reachable from the start node.
    /// - Ensures that all paths eventually lead to an ``EndNode``.
    ///
    /// - Throws: An error if any validation check fails.
    func validate() throws {
        try checkDAG()
        try checkUnusedNodes()
        try checkEndToStartPath()
    }

    // TODO: Implement DAG check.
    /// Checks for cycles in the workflow graph.
    private func checkDAG() throws {

    }

    // TODO: Implement unused nodes check.
    /// Checks for nodes that are not reachable from the start node.
    private func checkUnusedNodes() throws {

    }

    // TODO: Implement end-to-start path check.
    /// Ensures all paths terminate at an ``EndNode``.
    private func checkEndToStartPath() throws {

    }

}
