//
//  Node+End.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

public struct EndNode: Node {
    public let id: ID
    public let name: String?
    public let type: NodeType = .END

    enum CodingKeys: CodingKey {
        case id
        case name
        case type
    }

    public init(id: ID, name: String?) {
        self.id = id
        self.name = name
    }
}
