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
        public let condition: Condition
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
//        try container.encode(variables, forKey: .variables)
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

//extension Node {
//    public func run(content: Context) async throws {
//        fatalError("Not Implemented!")
//    }
//}


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
    
    public func run(context: inout Context, input: [DataKeyPath: FlowData]) async throws -> OutputPipe {
        
        let startNode = try requireStartNode()
        // only start node know input, it should inital context and validate it.
        try StartNode.initialContext(&context, with: input) // can the method move to node itself ?
        
        // Start the workflow
        var currentNode: (any Node)? = startNode
        while let node = currentNode {
            
            let pipe = try await node.run(context: &context)
            
            let mustAtEnd = testIfReachTheEnd(id: node.id)
            
            if mustAtEnd {
                return pipe
            }
            
            if let variable = try await node.wait(pipe) {
                let encoder = AnyEncoder()
                if let result = try encoder.encode(variable) {
                    context.update(keyPath: [.init(node.id), DataKeyPath.NodeRunResultKey], value: result)
                }
            }
            
            let edge = try matchEdge(id: node.id, context: context)
            
            guard let nextNode = self.nodes[edge.to] else {
                break
            }
            
            currentNode = nextNode
        }
        
        throw Err.CanNotMatchAnEdge
    }
    
    public func matchEdge(id: Node.ID, context: Context) throws -> Edge {
        let edges = flows[id]
        guard let edge = edges?.first(where: { $0.condition.eval(context.filter(keys: nil).mapKeysAsString()) }) else {
            throw Err.CanNotMatchAnEdge
        }
        
        return edge
    }
    
    public func testIfReachTheEnd(id: Node.ID) -> Bool {
        let edges = flows[id]
        
        guard let edges, edges.count == 1,
              let edge = edges.first,
              let node = self.nodes[edge.to],
              node is EndNode
        else {
            return false
        }
        return true
    }
    
}
