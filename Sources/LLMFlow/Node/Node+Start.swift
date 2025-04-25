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

    public static func initialContext(_ context: inout Context, with store: Context.Store) throws {
        context.store.merge(store) { $1 }
    }

    public func run(context: inout Context) async throws -> OutputPipe {
        try Self.verify(store: context.store, decls: self.input)
        return .none
    }
    
    enum InitVerifyErr: Error, Hashable {
        case inputDataNotFound(key: String)
        case inputDataTypeMissMatch(key: String)
        case other(String)
    }
    
    public static func verify(
        store: Context.Store,
        decls: [Context.Key: FlowData.TypeDecl]
    ) throws {
        for (key, decl) in decls {
            guard let data = store[key] else {
                throw InitVerifyErr.inputDataNotFound(key: key)
            }
            
            guard data.decl == decl else {
                throw InitVerifyErr.inputDataTypeMissMatch(key: key)
            }
        }
    }
}
