//
//  Node+Start.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

public struct StartNode: Node {
    public let id: ID
    public let name: String?
    public let type: NodeType

    public let inputs: [Context.Key: FlowData.TypeDecl]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(StartNode.ID.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.type = try container.decode(NodeType.self, forKey: .type)
        self.inputs = try container.decode([Context.Key: FlowData.TypeDecl].self, forKey: .inputs)
    }

    public init(id: StartNode.ID, name: String? = nil, inputs: [Context.Key: FlowData.TypeDecl]) {
        self.id = id
        self.name = name
        self.type = .START
        self.inputs = inputs
    }
}
