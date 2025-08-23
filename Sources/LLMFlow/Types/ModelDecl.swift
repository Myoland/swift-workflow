import LazyKit


/// Defines the type of a key in a ``ModelDecl`` body, allowing for constants, references, and templates.
///
/// A `ModelDeclKey` interprets special prefixes on string keys to determine their behavior:
/// - `$` prefix: Indicates a reference to a value in the ``Context``. The key's value should be the path to the desired data.
/// - `#` prefix: Indicates a Jinja template. The key's value should be a template string to be rendered.
/// - No prefix: A constant key whose value is taken literally.
public enum ModelDeclKey: Sendable {
    /// A literal key.
    case constant(String)
    /// A key that references a value from the ``Context``.
    case ref(String)
    /// A key whose value is a Jinja template to be rendered.
    case template(String)
    
    /// Initializes a `ModelDeclKey` from a raw string, parsing prefixes.
    public init(_ rawValue: String) {
        if rawValue.starts(with: "$") {
            self = .ref(rawValue.replacing("$", with: "", maxReplacements: 1))
        } else if rawValue.starts(with: "#") {
            self = .template(rawValue.replacing("#", with: "", maxReplacements: 1))
        } else {
            self = .constant(rawValue)
        }
    }
}

extension ModelDeclKey: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .constant(let string):
            string
        case .ref(let string):
            "$\(string)"
        case .template(let string):
            "#\(string)"
        }
    }
    public init?(rawValue: String) {
        self.init(rawValue)
    }
}

extension ModelDeclKey: ExpressibleByStringLiteral {
    public init(stringLiteral rawValue: String) {
        self.init(rawValue)
    }
}


extension ModelDeclKey: CodingKeyRepresentable {}

extension ModelDeclKey: CustomStringConvertible {
    public var description: String { self.rawValue }
}

extension ModelDeclKey: Encodable {
    public func encode(to encoder: any Encoder) throws {
        try self.rawValue.encode(to: encoder)
    }
}

extension ModelDeclKey: Decodable {
    public init(from decoder: any Decoder) throws {
        let str = try String(from: decoder)
        self.init(str)
    }
}

extension ModelDeclKey: Equatable {
    public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension ModelDeclKey: Hashable {}

/// A declarative representation of a model's input parameters.
///
/// `ModelDecl` (Model Declaration) is used to construct the input payload for services like LLM providers.
/// It supports dynamically rendering values from the workflow's ``Context`` by using special key prefixes
/// defined by ``ModelDeclKey``.
///
/// This allows you to define a static structure for an API request while pulling in dynamic data at runtime.
///
/// ## Example
/// Consider an LLM node that needs to be configured with a model name from the workflow's inputs and a
/// system prompt from a template.
///
/// ```swift
/// let modelDecl = ModelDecl([
///     "model": .single(.string("$model_name")), // Reference to context value
///     "system_prompt": .single(.string("# Sarcastic assistant")), // Template
///     "temperature": .single(.double(0.8)) // Constant
/// ])
///
/// var context = Context()
/// context["model_name"] = "gpt-4"
///
/// let rendered = try modelDecl.render(context.store)
/// // rendered will be:
/// // [
/// //     "model": "gpt-4",
/// //     "system_prompt": "Sarcastic assistant",
/// //     "temperature": 0.8
/// // ]
/// ```
public struct ModelDecl: Codable, Sendable, Hashable {
    /// The dictionary defining the model's parameters. Keys may have special prefixes
    /// as interpreted by ``ModelDeclKey``.
    public let body: [String: FlowData]

    /// Renders the `body` dictionary using values from the provided context store.
    ///
    /// This method processes each key-value pair in the `body`, resolving references and rendering templates
    /// to produce a final dictionary of concrete values.
    ///
    /// - Parameter values: The context store containing the data for rendering.
    /// - Returns: A dictionary with rendered values.
    public func render(_ values: [String: AnySendable]) throws -> [String: Any?] {
        return try body.render(values)
    }
    
    /// Initializes a `ModelDecl` with a body dictionary.
    public init(_ body: [String: FlowData]) {
        self.body = body
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.body = try container.decode([String : FlowData].self)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.body)
    }
}

// MARK: Context Render

extension Dictionary where Key == String, Value == FlowData {
    fileprivate func render(_ values: Context.Store) throws -> Context.Store {
        var result: Context.Store = [:]
        
        for (key, value) in self {
            let modelDeclKey = ModelDeclKey(key)
            
            switch modelDeclKey {
            case .constant(let contant):
                result[contant] = try value.render(values)
            case .ref(let ref):
                let value = value.asAny
                
                if let key = value as? String {
                    result[ref] = values[path: ContextStorePath(key)]
                } else if let keys = value as? [String] {
                    result[ref] = values[path: keys]
                }
                
            case .template(let key):
                if let templateStr = value.stringValue {
                    let template = Template(content: templateStr)
                    result[key] = try template.render(values)
                }
            }
        }
        
        return result
    }
}

extension FlowData {
    fileprivate func render(_ values: Context.Store) throws -> AnySendable {
        switch self {
        case .single(let single):
            return single.asAny
        case .list(let list):
            return try list.render(values)
        case .map(let map):
            return try map.render(values)
        }
    }
}

extension FlowData.Map {
    fileprivate func render(_ values: Context.Store) throws -> [String: AnySendable] {
        return try elememts.render(values)
    }
}

extension FlowData.List {
    fileprivate func render(_ values: Context.Store) throws -> [AnySendable] {
        return try self.elements.map { try $0.render(values) }
    }
}
