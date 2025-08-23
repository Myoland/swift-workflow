//
//  Node+End.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

struct EndNode: Node {

    let id: ID
    let name: String?
    let type: NodeType = .END

    enum CodingKeys: CodingKey {
        case id
        case name
        case type
    }

    func run(executor: Executor) async throws -> NodeOutput? { nil }

    func update(_ context: Context, value: Context.Value) throws {}
}
