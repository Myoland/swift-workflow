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

extension StartNode {


    public func run(executor: Executor) async throws -> NodeOutput? {
        let payload = executor.context.payload.withLock({ $0 })

        guard let value = payload?.value as? [Context.Key: FlowData] else {
            return .none
        }

        executor.logger.debug("[*] Start Node. Values: \(value)")

        try verify(data: value)

        executor.logger.info("[*] Start Node. Verify Success.")
        return .block(value.asAny)
    }

    public func update(_ context: Context, value: Context.Value) throws {
        context[path: ContextStoreKey.WorkflowInputsKeyPath] = value
    }

    public func verify(
        data: [ContextStoreKey: FlowData]
    ) throws {
        try Self.verify(data: data, decls: self.inputs)
    }

    public static func verify(
        data: [ContextStoreKey: FlowData],
        decls: [ContextStoreKey: FlowData.TypeDecl]
    ) throws {
        for (key, decl) in decls {
            guard let data = data[key] else {
                throw VerifyErr.inputDataNotFound(key: key)
            }

            guard data.decl == decl else {
                throw VerifyErr.inputDataTypeMissMatch(key: key, expect: decl, actual: data)
            }
        }
    }
}

extension StartNode {
    enum VerifyErr: Error, Hashable {
        case inputDataNotFound(key: String)
        case inputDataTypeMissMatch(key: String, expect: FlowData.TypeDecl, actual: FlowData?)
        case other(String)
    }
}


extension StartNode.VerifyErr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .inputDataNotFound(let key):
            return "Key Not Found For Key: '\(key)'."
        case .inputDataTypeMissMatch(let key, let expect, let actual):
            return "Data Type Miss Match For Key: '\(key)'. Expected: \(expect), Actual: \(actual ?? "nil")"
        case .other(let message):
            return "Unknown Error: \(message)."
        }
    }
}
