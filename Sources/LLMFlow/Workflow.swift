import Foundation
import Logging
import LazyKit


// MARK: Workflow + Edge

extension Workflow {
    /// A collection of `Edge` instances that define the connections between nodes in a ``Workflow``.
    public typealias Edges = [Edge]

    /// Represents a directed connection from one ``Node`` to another within a ``Workflow``.
    ///
    /// An edge may include an optional ``Condition`` that must be met for the workflow to traverse this path.
    public struct Edge : Sendable {
        /// The identifier of the node where the edge originates.
        public let from: Node.ID
        /// The identifier of the node where the edge terminates.
        public let to: Node.ID
        /// An optional condition that must evaluate to `true` for this edge to be taken.
        /// If `nil`, the edge is considered unconditional.
        public let condition: Condition?
    }
}

extension Workflow.Edge: Codable {}
extension Workflow.Edge: Hashable {}

// MARK: Workflow

/// A directed acyclic graph (DAG) of runnable nodes that defines a flow of execution for large language model (LLM) tasks.
///
/// A `Workflow` is the central component of the LLMFlow library. It orchestrates the execution of various ``Node`` types,
/// manages the flow of data through a ``Context``, and handles conditional branching via ``Edge``s.
///
/// ## Overview
/// A workflow consists of:
/// - A collection of ``Node``s, each representing a specific task (e.g., starting the flow, processing a template, calling an LLM).
/// - A set of ``Edge``s that define the valid transitions between nodes.
/// - A single designated ``StartNode`` that serves as the entry point.
/// - A ``ServiceLocator`` for dependency injection, providing services like model providers.
///
/// Workflows are typically constructed from a ``Workflow/Config`` object but can also be initialized directly.
///
/// ## Execution
/// To run a workflow, call the ``run(inputs:context:)`` method, which returns an `AsyncSequence` of ``PipeState`` updates,
/// allowing you to observe the state of the workflow as it executes each node.
///
/// ## Example
/// ```swift
/// // Example of building and running a simple workflow (conceptual).
/// // For a concrete example, see the integration tests.
///
/// let startNode = StartNode(id: "start")
/// let llmNode = LLMNode(id: "llm", model: .init(provider: .openAI(.gpt4)))
/// let endNode = EndNode(id: "end")
///
/// let edges = [
///     Workflow.Edge(from: startNode.id, to: llmNode.id, condition: nil),
///     Workflow.Edge(from: llmNode.id, to: endNode.id, condition: nil)
/// ]
///
/// let nodes: [String: any RunnableNode] = [
///     startNode.id: startNode,
///     llmNode.id: llmNode,
///     endNode.id: endNode
/// ]
///
/// let workflow = Workflow(
///     nodes: nodes,
///     flows: [startNode.id: [edges[0]], llmNode.id: [edges[1]]],
///     startNodeID: startNode.id,
///     locator: myServiceLocator
/// )
///
/// let updates = try workflow.run(inputs: ["query": "Hello, world!"])
/// for try await update in updates {
///     print("Node \(update.node.id) finished with state \(update.type)")
/// }
/// ```
///
public struct Workflow : Sendable {

    /// A dictionary of all nodes in the workflow, keyed by their unique identifiers.
    public let nodes: [Node.ID: any RunnableNode]
    /// A dictionary mapping each node ID to its outgoing edges.
    public let flows: [Node.ID: Edges]

    /// The identifier of the ``StartNode``, which is the entry point of the workflow.
    public let startNodeID: Node.ID

    /// The service locator used to resolve dependencies, such as API providers for LLM nodes.
    public let locator: ServiceLocator
    
    /// The logger used for logging workflow execution details.
    public let logger: Logger

    /// Initializes a new workflow with the specified components.
    ///
    /// - Parameters:
    ///   - nodes: A dictionary of nodes, keyed by their ID.
    ///   - flows: A dictionary mapping node IDs to their outgoing edges.
    ///   - startNodeID: The ID of the designated ``StartNode``.
    ///   - locator: A service locator for dependency resolution.
    ///   - logger: An optional logger. If `nil`, a default internal logger is used.
    public init(
        nodes: [Node.ID : any RunnableNode],
        flows: [Node.ID : Edges],
        startNodeID: Node.ID,
        locator: ServiceLocator,
        logger: Logger? = nil
    ) {
        self.nodes = nodes
        self.flows = flows
        self.startNodeID = startNodeID
        self.locator = locator
        self.logger = logger ?? Logger.Internal
    }
}

extension Workflow {
    /// Retrieves the ``StartNode`` of the workflow.
    ///
    /// - Throws: ``RuntimeError/StartNodeNotFound`` if the node corresponding to `startNodeID` is not found or is not a `StartNode`.
    /// - Returns: The ``StartNode`` instance.
    public func requireStartNode() throws -> StartNode  {
        guard let node = nodes[startNodeID] as? StartNode else {
            throw RuntimeError.StartNodeNotFound
        }
        return node
    }
}
