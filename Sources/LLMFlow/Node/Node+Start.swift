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

    public func run(context: Context, pipe: OutputPipe) async throws -> OutputPipe {
        guard case .block(let value) = pipe,
              let value = value as? [NodeVariableKey: FlowData]
        else {
            return .none
        }
        
        try verify(data: value)
        return .block(value)
    }
    
    public func update(_ context: inout Context, value: Context.Value) throws {
        guard let value = value as? [NodeVariableKey: FlowData] else {
            return
        }
        
        context[path: "inputs"] = value.asAny
        
    }
    
    enum InitVerifyErr: Error, Hashable {
        case inputDataNotFound(key: String)
        case inputDataTypeMissMatch(key: String)
        case other(String)
    }

    public func verify(
        data: [DataKeyPath: FlowData]
    ) throws {
        try Self.verify(data: data, decls: self.input)
    }

    public static func verify(
        data: [DataKeyPath: FlowData],
        decls: [DataKeyPath: FlowData.TypeDecl]
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
