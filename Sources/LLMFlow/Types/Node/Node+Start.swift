//
//  Node+Start.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

/// A node that defines the starting point of a workflow and its required inputs.
///
/// `StartNode` declares the keys and types that must exist in the ``Context``
/// before execution begins. It is a schema/contract-only node and is not executed.
/// Its ``NodeType`` is expected to be `.START`.
///
/// The verified values will be store in path `workflow.inputs`
public struct StartNode: Node {
    /// Stable node identifier used for graph wiring and result addressing.
    ///
    /// See ``Node/resultKeyPaths`` for how results are stored using this identifier.
    public let id: ID

    /// Optional human-readable name for display/debugging purposes.
    public let name: String?

    /// The node kind. For `StartNode` this should always be `.START`.
    public let type: NodeType

    /// The input schema available at workflow start.
    ///
    /// Maps a ``Context/Key`` to a ``FlowData/TypeDecl`` describing the expected
    /// value type present in the initial context.
    public let inputs: [Context.Key: FlowData.TypeDecl]

    /// Decodes a `StartNode` from a serialized workflow definition.
    ///
    /// - Note: The decoded `type` is expected to be `.START`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(StartNode.ID.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.type = try container.decode(NodeType.self, forKey: .type)
        self.inputs = try container.decode([Context.Key: FlowData.TypeDecl].self, forKey: .inputs)
    }

    /// Creates a `StartNode`.
    ///
    /// - Parameters:
    ///   - id: Stable node identifier.
    ///   - name: Optional display name.
    ///   - inputs: Mapping of input keys to type declarations that must be present at the start.
    /// - Note: `type` is set to `.START`.
    public init(id: StartNode.ID, name: String? = nil, inputs: [Context.Key: FlowData.TypeDecl]) {
        self.id = id
        self.name = name
        self.type = .START
        self.inputs = inputs
    }
}
