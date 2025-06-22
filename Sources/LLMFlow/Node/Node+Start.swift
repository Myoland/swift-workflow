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

    public let inputs: [NodeVariableKey: FlowData.TypeDecl]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(StartNode.ID.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.type = try container.decode(NodeType.self, forKey: .type)
        self.inputs = try container.decode([NodeVariableKey: FlowData.TypeDecl].self, forKey: .inputs)
    }

    public init(id: StartNode.ID, name: String? = nil, inputs: [NodeVariableKey: FlowData.TypeDecl]) {
        self.id = id
        self.name = name
        self.type = .START
        self.inputs = inputs
    }
}

extension StartNode {


    public func run(executor: Executor) async throws {
        let context = executor.context

        guard case .block(let value) = context.pipe.withLock({ $0 }),
              let value = value as? [NodeVariableKey: FlowData]
        else {
            return
        }

        try verify(data: value)
        context.pipe.withLock { $0 = .block(value.asAny) }
    }
    
    static public let resultKey: String = "inputs"
    
    public func update(_ context: Context, value: Context.Value) throws {
        context[path: Self.resultKey] = value
    }

    enum InitVerifyErr: Error, Hashable {
        case inputDataNotFound(key: String)
        case inputDataTypeMissMatch(key: String)
        case other(String)
    }

    public func verify(
        data: [DataKeyPath: FlowData]
    ) throws {
        try Self.verify(data: data, decls: self.inputs)
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
