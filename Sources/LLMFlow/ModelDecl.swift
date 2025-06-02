import LazyKit


public enum ModelDeclKey: Sendable {
    case constant(String)
    case ref(String)
    case template(String)
    
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

public struct ModelDecl: Codable, Sendable, Hashable {
    let body: [String: FlowData]

    public func render(_ values: [String: Any]) throws -> [String: Any] {
        return try body.render(values)
    }
    
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

extension Dictionary where Key == String, Value == FlowData {
    fileprivate func render(_ values: [String: Any]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in self {
            let modelDeclKey = ModelDeclKey(key)
            
            switch modelDeclKey {
            case .constant(let contant):
                result[contant] = try value.render(values)
            case .ref(let ref):
                let value = value.asAny
                
                if let key = value as? String {
                    result[ref] = values[key]
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
    fileprivate func render(_ values: [String: Any]) throws -> Any {
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
    fileprivate func render(_ values: [String: Any]) throws -> [String: Any] {
        return try elememts.render(values)
    }
}

extension FlowData.List {
    fileprivate func render(_ values: [String: Any]) throws -> [Any] {
        return try self.elements.map { try $0.render(values) }
    }
}

