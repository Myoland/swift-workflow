import Foundation
import os.log
import LazyKit

//protocol Predictable {
//    associatedtype CompareType
//    func evaluate(with: CompareType) -> Bool
//}

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

public struct Workflow {
    public typealias VariableKey = NodeVariableKey
    public typealias VariableValue = Context.Value

    let nodes: [Node.ID: any Node]
    let flows: [Node.ID: Edges]
    
    let startNodeID: Node.ID
}

extension Workflow {
    public struct Config {

//        public let variables: [VariableKey: VariableValue]
        public let nodes: [any Node]

        public let edges: [Edge]
    }
}

extension Workflow.Config: Hashable {
    public static func == (lhs: Workflow.Config, rhs: Workflow.Config) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        // hasher.combine(variables)
        hasher.combine(edges)
        for node in nodes {
            hasher.combine(node)
        }
    }
}

extension Workflow.Config: Codable {
    enum CodingKeys: CodingKey {
//        case variables
        case nodes
        case edges
    }

    enum NodeKeys: CodingKey {
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.variables = try container.decode([Workflow.VariableKey: Workflow.VariableValue].self, forKey: .variables)
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

extension Workflow {
    public static func buildWorkflow(config: Workflow.Config) throws -> Workflow {
        try config.validate()
        
        let startNode = try config.requireStartNode()
        
        return .init(nodes: [:], flows: [:], startNodeID: startNode.id)
    }
}

extension Workflow.Config {
    enum Err: Error {
        case missingStartNode
        case typeMissMatchStartNode
    }


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

extension Workflow {
    enum Err: Error {
        case StartNodeNotFound
        case CanNotMatchAnEdge
        case NextNodeNotFound
    }
}

extension Workflow {
    
    public func requireStartNode() throws -> StartNode  {
        guard let node = nodes[startNodeID] as? StartNode else {
            throw Err.StartNodeNotFound
        }
        return node
    }
    
}

extension Workflow {
    
    public func run(context: inout Context) async throws -> OutputPipe {
        
        let startNode = try requireStartNode()
        
        var pipe: OutputPipe = .none
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
