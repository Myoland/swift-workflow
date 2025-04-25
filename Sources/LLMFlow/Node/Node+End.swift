//
//  Node+End.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

struct EndNode: Node {
    let id: ID
    let name: String?
    let type: NodeType
    
    init(id: ID, name: String?) {
        self.id = id
        self.name = name
        self.type = .END
    }
}
