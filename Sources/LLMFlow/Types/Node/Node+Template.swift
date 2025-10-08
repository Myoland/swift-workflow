//
//  Node+Template.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

import Jinja

/// A wrapper for a Jinja template string that provides rendering capabilities.
///
/// This struct is used by the ``TemplateNode`` to process text using the Jinja templating engine.
/// It can be initialized directly from a string or a string literal.
public struct Template: Codable, ExpressibleByStringLiteral, Hashable, Sendable {
    /// The raw Jinja template string.
    let content: String
    // TODO: validate input

    /// Initializes a `Template` using a string literal.
    public init(stringLiteral value: String) {
        self.content = value
    }

    /// Initializes a `Template` with a given content string.
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

    /// Converts the raw content into a `Jinja.Template` object.
    /// - Throws: An error if the template content is invalid.
    public func toJinja() throws -> Jinja.Template {
        try Jinja.Template(content)
    }

    /// Renders the Jinja template with a given context dictionary.
    /// - Parameter items: A dictionary of values to be used in rendering the template.
    /// - Throws: An error if rendering fails.
    /// - Returns: The rendered string.
    public func render(_ items: [String: Any]) throws -> String {
        let context: [String: Jinja.Value] = items.compactMapValues { try? .init(any: $0) }
        return try toJinja().render(context)
    }
}

/// A node that processes a Jinja template.
///
/// A `TemplateNode` takes a ``Template`` and renders it using data from the ``Context``.
/// The rendered output is then placed back into the context for subsequent nodes to use.
public struct TemplateNode: Node {
    public let id: ID
    public let name: String?
    public let type: NodeType

    public let template: Template

    public init(id: ID, name: String?, template: Template) {
        self.id = id
        self.name = name
        self.type = .TEMPLATE
        self.template = template
    }
}
