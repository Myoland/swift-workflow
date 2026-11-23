//
//  Workflow+Build.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

import Algorithms
import Logging

public extension Workflow {
    /// Initializes a ``Workflow`` from a configuration object.
    ///
    /// This initializer provides a convenient way to construct a workflow from a ``Workflow/Config``,
    /// which is often decoded from a file (e.g., YAML or JSON). It extracts the nodes and edges,
    /// and constructs the `Workflow` instance. Call ``Workflow/Config/validate()`` first to find
    /// problems that would make a run fail (dead ends, cycles, unreachable nodes, …).
    ///
    /// - Parameters:
    ///   - config: The ``Workflow/Config`` object describing the workflow's structure.
    ///   - locator: A service locator for dependency resolution.
    ///   - logger: An optional logger.
    /// - Throws: ``ConstructError`` if the configuration does not have exactly one start node.
    init(config: Workflow.Config, locator: ServiceLocator, logger: Logger? = nil) throws {
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
        nodes.filter { $0.type == type }
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
}
