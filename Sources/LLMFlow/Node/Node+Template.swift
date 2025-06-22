//
//  Node+Template.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

import Jinja

public struct Template: Codable, ExpressibleByStringLiteral, Hashable, Sendable {
    let content: String
    // TODO: validate input

    public init(stringLiteral value: String) {
        self.content = value
    }

    public init(content: String) {
        self.content = content
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.content = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(content)
    }

    public func toJinja() throws -> Jinja.Template {
        try Jinja.Template(content)
    }

    public func render(_ items: [String: Any]) throws -> String {
        try toJinja().render(items)
    }
}

struct TemplateNode: Node {
    let id: ID
    let name: String?
    let type: NodeType

    let template: Template

    init(id: ID, name: String?, template: Template) {
        self.id = id
        self.name = name
        self.type = .TEMPLATE
        self.template = template
    }
}

extension TemplateNode {

    public func run(executor: Executor) async throws {
        let context = executor.context

        let result = try template.render(context.filter(keys: nil))
        context.pipe.withLock({
            $0 = .block(result)
        })
    }
    
    func update(_ context: Context, value: any Context.Value) throws {
        try self.updateIntoResult(context, value: value)
    }
}
