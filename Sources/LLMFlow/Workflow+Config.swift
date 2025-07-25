//
//  Workflow+Config.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

extension Workflow {
    public struct Config {

        public let nodes: [any Node]

        public let edges: [Edge]

        public init(nodes: [any Node], edges: [Edge]) {
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
    enum CodingKeys: CodingKey {
        case nodes
        case edges
    }

    enum NodeKeys: CodingKey {
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.edges = try container.decode([Workflow.Edge].self, forKey: .edges)

        var nested = try container.nestedUnkeyedContainer(forKey: .nodes)

        var nodes: [any Node] = []
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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var nested = container.nestedUnkeyedContainer(forKey: .nodes)
        for node in nodes {
            try nested.encode(node)
        }
        try container.encode(edges, forKey: .edges)
    }
}
