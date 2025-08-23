//
//  Workflow+Config.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

extension Workflow {
    /// A serializable configuration for a ``Workflow``.
    ///
    /// This structure is used to define a workflow's nodes and edges in a way that can be easily
    /// encoded to and decoded from formats like YAML or JSON. This is the primary mechanism for
    /// defining persistent, reusable workflows.
    ///
    /// ## Decoding Heterogeneous Nodes
    /// The `Codable` implementation for `Config` handles the complexity of decoding an array of different
    /// ``Node`` types. It uses a `type` field on each node object to determine which concrete `Node`
    /// subclass to instantiate.
    ///
    /// ## Example
    /// A YAML representation of a `Config` might look like this:
    /// ```yaml
    /// nodes:
    ///   - id: "start"
    ///     type: "START"
    ///     inputs: []
    ///   - id: "llm"
    ///     type: "LLM"
    ///     model:
    ///       provider: "openAI"
    ///       name: "gpt-4"
    /// edges:
    ///   - from: "start"
    ///     to: "llm"
    /// ```
    ///
    /// - SeeAlso: ``Workflow/init(config:locator:logger:)``
    public struct Config {

        /// An array of all nodes in the workflow.
        public let nodes: [any RunnableNode]

        /// An array of all edges connecting the nodes.
        public let edges: [Edge]

        /// Initializes a new workflow configuration.
        ///
        /// - Parameters:
        ///   - nodes: The nodes of the workflow.
        ///   - edges: The edges connecting the nodes.
        public init(nodes: [any RunnableNode], edges: [Edge]) {
            self.nodes = nodes
            self.edges = edges
        }
    }
}

extension Workflow.Config: Hashable {
    public static func == (lhs: Workflow.Config, rhs: Workflow.Config) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(edges)
        for node in nodes {
            hasher.combine(node)
        }
    }
}

extension Workflow.Config: Codable {
    private enum CodingKeys: CodingKey {
        case nodes
        case edges
    }

    private enum NodeKeys: CodingKey {
        case type
    }

    /// Decodes a `Config` instance, handling the decoding of various concrete ``Node`` types.
    ///
    /// This initializer inspects a `type` field in each node's JSON/YAML representation to determine
    /// which `Node` subclass to decode.
    ///
    /// - Throws: `DecodingError` if the `type` field is missing or unknown, or if any node fails to decode.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.edges = try container.decode([Workflow.Edge].self, forKey: .edges)

        var nested = try container.nestedUnkeyedContainer(forKey: .nodes)

        var nodes: [any RunnableNode] = []
        while !nested.isAtEnd {
            let nodeDecoder = try nested.superDecoder()

            let nodeTypeContainer = try nodeDecoder.container(keyedBy: NodeKeys.self)
            let nodeType = try nodeTypeContainer.decode(NodeType.self, forKey: .type)

            switch nodeType {
            case .START:
                let node = try StartNode(from: nodeDecoder)
                nodes.append(node)
            case .END:
                let node = try EndNode(from: nodeDecoder)
                nodes.append(node)
            case .TEMPLATE:
                let node = try TemplateNode(from: nodeDecoder)
                nodes.append(node)
            case .LLM:
                let node = try LLMNode(from: nodeDecoder)
                nodes.append(node)
            default:
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown node type"))
            }
        }
        self.nodes = nodes
    }

    /// Encodes the `Config` instance.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var nested = container.nestedUnkeyedContainer(forKey: .nodes)
        for node in nodes {
            try nested.encode(node)
        }
        try container.encode(edges, forKey: .edges)
    }
}
