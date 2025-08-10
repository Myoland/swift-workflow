import Foundation
import Logging
import LazyKit


// MARK: Workflow + Edge

extension Workflow {
    public typealias Edges = [Edge]

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

    public let nodes: [Node.ID: any Node]
    public let flows: [Node.ID: Edges]

    public let startNodeID: Node.ID

    public let locator: ServiceLocator
    
    public let logger: Logger

    public init(
        nodes: [Node.ID : any Node],
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
    public func requireStartNode() throws -> StartNode  {
        guard let node = nodes[startNodeID] as? StartNode else {
            throw RuntimeError.StartNodeNotFound
        }
        return node
    }
}
