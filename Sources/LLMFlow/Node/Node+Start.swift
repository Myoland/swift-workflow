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

    public let input: [NodeVariableKey: FlowData.TypeDecl]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(StartNode.ID.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.type = try container.decode(NodeType.self, forKey: .type)
        self.input = try container.decode([NodeVariableKey: FlowData.TypeDecl].self, forKey: .input)
    }

    public init(id: StartNode.ID, name: String? = nil, input: [NodeVariableKey: FlowData.TypeDecl]) {
        self.id = id
        self.name = name
        self.type = .START
        self.input = input
    }
}

extension StartNode {

    public static func initialContext(_ context: inout Context, with input: [String: FlowData]) throws {
        for (key, value) in input {
            context.update(key: key, value: value)
        }
    }

    public func run(context: inout Context) async throws -> OutputPipe {
        try verify(data: context.filter(keys: [], as: FlowData.self))
        return .none
    }

    enum InitVerifyErr: Error, Hashable {
        case inputDataNotFound(key: String)
        case inputDataTypeMissMatch(key: String)
        case other(String)
    }

    public func verify(
        data: [String: FlowData]
    ) throws {
        try Self.verify(data: data, decls: self.input)
    }

    public static func verify(
        data: [String: FlowData],
        decls: [Context.Key: FlowData.TypeDecl]
    ) throws {
        for (key, decl) in decls {
            guard let data = data[key] else {
                throw InitVerifyErr.inputDataNotFound(key: key)
            }

            guard data.decl == decl else {
                throw InitVerifyErr.inputDataTypeMissMatch(key: key)
            }
        }
    }
}
