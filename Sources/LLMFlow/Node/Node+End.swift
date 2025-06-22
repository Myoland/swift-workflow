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

    public func run(executor: Executor) async throws {}
    
    func update(_ context: Context, value: any Context.Value) throws {
    }
}
