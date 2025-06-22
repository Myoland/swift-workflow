import Foundation
import os.log
import LazyKit


// MARK: Workflow + Edge

extension Workflow {
    typealias Edges = [Edge]

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

    let nodes: [Node.ID: any Node]
    let flows: [Node.ID: Edges]

    let startNodeID: Node.ID

    let locator: ServiceLocator
}

extension Workflow {

    public func requireStartNode() throws -> StartNode  {
        guard let node = nodes[startNodeID] as? StartNode else {
            throw Err.StartNodeNotFound
        }
        return node
    }

}
