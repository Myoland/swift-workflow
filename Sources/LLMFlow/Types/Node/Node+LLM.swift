//
//  Node+LLM.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//
//
//


struct LLMNode: ResultResaveableNode {
    let id: ID
    let name: String?
    let type: NodeType

    let modelName: String

    let output: String?

    let request: ModelDecl

    init(
        id: ID,
        name: String?,
        modelName: String,
        output: String?,
        request: ModelDecl
    ) {
        self.id = id
        self.name = name
        self.type = .LLM
        self.modelName = modelName
        self.output = output
        self.request = request
    }
}
