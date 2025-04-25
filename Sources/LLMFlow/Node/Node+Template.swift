//
//  Node+Template.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

import Jinja

struct Template: Codable, ExpressibleByStringLiteral, Hashable {
    let content: String
    // TODO: validate input

    init(stringLiteral value: String) {
        self.content = value
    }

    init(content: String) {
        self.content = content
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.content = try container.decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(content)
    }

    func toJinja() throws -> Jinja.Template {
        try Jinja.Template(content)
    }

    public func render(_ items: Context.Store) throws -> String {
        try toJinja().render(items.asAny)
    }
}

struct TemplateNode: Node {
    let id: ID
    let name: String?
    let type: NodeType

    let template: Template
    let output: NodeVariableKey

    init(id: ID, name: String?, template: Template, output: NodeVariableKey) {
        self.id = id
        self.name = name
        self.type = .TEMPLATE
        self.template = template
        self.output = output
    }
}

extension TemplateNode {
    func run(context: inout Context) async throws -> OutputPipe {
        let result = try template.render(context.store)

        return .block(
            key: output,
            value: .single(.string(result))
        )
    }
}
