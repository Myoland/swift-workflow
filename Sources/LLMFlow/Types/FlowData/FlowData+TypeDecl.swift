public extension FlowData {
    indirect enum TypeDecl: Hashable, Sendable {
        public typealias Single = FlowData.Single.TypeDecl

        case single(Single)
        case list(TypeDecl)
        case map(TypeDecl)
        case any
    }
}

public extension FlowData.Single {
    enum TypeDecl: Hashable, Sendable {
        case bool
        case int
        case string
        case any
    }
}

extension FlowData.TypeDecl: LosslessStringConvertible {
    public init?(_ description: String) {
        let listPattern = #/^\[(\w+)\]$/#
        let mapPattern = #/^\[String: ?(\w+)\]$/#

        if let singleDecl = Self.Single(description) {
            self = .single(singleDecl)
            return
        } else if let match = description.wholeMatch(of: listPattern) {
            let innerType = String(match.1)
            if let innerDecl = Self(innerType) {
                self = .list(innerDecl)
                return
            }
            return nil
        } else if let match = description.wholeMatch(of: mapPattern) {
            let innerType = String(match.1)
            if let innerDecl = Self(innerType) {
                self = .map(innerDecl)
                return
            }
            return nil
        }

        return nil
    }

    // Example:
    //  - single(int) -> Int
    //  - list(single(int)) -> [Int]
    //  - map(single(int)) -> [String:Int]
    public var description: String {
        switch self {
        case .single(let decl):
            "\(decl.description)"
        case .list(let decl):
            "[\(decl.description)]"
        case .map(let decl):
            "[String: \(decl.description)]"
        case .any:
            "Any"
        }
    }
}

extension FlowData.Single.TypeDecl: LosslessStringConvertible {
    public init?(_ description: String) {
        switch description {
        case "Int":
            self = .int
        case "String":
            self = .string
        case "Any":
            self = .any
        default:
            return nil
        }
    }

    public var description: String {
        switch self {
        case .bool:
            "Bool"
        case .int:
            "Int"
        case .string:
            "String"
        case .any:
            "Any"
        }
    }
}

extension FlowData.Single.TypeDecl: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let description = try container.decode(String.self)
        self.init(description)!
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension FlowData.TypeDecl: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let description = try container.decode(String.self)
        self.init(description)!
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

// MARK: FlowData + TypeDecl

extension FlowData {
    var decl: TypeDecl {
        switch self {
        case .single(let single):
            .single(single.decl)
        case .list(let list):
            list.decl
        case .map(let map):
            map.decl
        }
    }
}

extension FlowData.Single {
    var decl: FlowData.Single.TypeDecl {
        switch self {
        case .bool:
            .bool
        case .int:
            .int
        case .string:
            .string
        }
    }
}

extension FlowData.List {
    var decl: Element.TypeDecl {
        .list(elemDecl)
    }
}

extension FlowData.Map {
    var decl: Value.TypeDecl {
        .map(elemDecl)
    }
}

extension Collection<FlowData> {
    var decl: Element.TypeDecl {
        .LCA(decls: map(\.decl))
    }
}

extension FlowData.TypeDecl {
    var isSingle: Bool {
        switch self {
        case .single:
            true
        default:
            false
        }
    }

    var single: FlowData.Single.TypeDecl? {
        switch self {
        case .single(let single):
            single
        default:
            nil
        }
    }
}

extension FlowData.TypeDecl {
    var isList: Bool {
        switch self {
        case .list:
            true
        default:
            false
        }
    }

    var list: FlowData.TypeDecl? {
        switch self {
        case .list(let decl):
            decl
        default:
            nil
        }
    }
}

extension FlowData.TypeDecl {
    var isMap: Bool {
        switch self {
        case .map:
            true
        default:
            false
        }
    }

    var map: FlowData.TypeDecl? {
        switch self {
        case .map(let decl):
            decl
        default:
            nil
        }
    }
}

extension FlowData.TypeDecl {
    /// Calculate least common ancestor (most specific common type declaration).
    ///
    /// Example:
    /// ```
    /// LCA([.single(int), .single(int)]) = .single(int)
    /// LCA([.single(int), .single(string)]) = .single(.any)
    /// LCA([.list(.single(string)), .list(.single(string))]) = .list(.single(string))
    /// LCA([.list(.single(int)), .list(.single(string))]) = .list(.any)
    /// LCA([.list(.single(int)), .map(.any)]) = .any
    /// ```
    static func LCA(decls: [FlowData.TypeDecl]) -> FlowData.TypeDecl {
        let decls = Set(decls)

        if decls.isEmpty {
            return .any
        }

        if decls.count == 1, let decl = decls.first {
            return decl
        }

        // Check if all declarations are of the same category (single, list, or map)
        let allSingles = decls.allSatisfy(\.isSingle)
        let allLists = decls.allSatisfy(\.isList)
        let allMaps = decls.allSatisfy(\.isMap)

        if allSingles {
            let singleDecls = decls.compactMap(\.single)
            return .single(FlowData.Single.TypeDecl.LCA(singleDecls))
        } else if allLists {
            let elementDecls = decls.compactMap(\.list)
            return .list(FlowData.TypeDecl.LCA(decls: elementDecls))
        } else if allMaps {
            let elementDecls = decls.compactMap(\.map)
            return .map(FlowData.TypeDecl.LCA(decls: elementDecls))
        }

        // If we reach here, declarations are of different categories
        return .any
    }
}

extension FlowData.Single.TypeDecl {
    /// Find LCA for single type declarations
    static func LCA(_ decls: [FlowData.Single.TypeDecl])
        -> FlowData.Single.TypeDecl
    {
        let uniqueDecls = Set(decls)

        if uniqueDecls.isEmpty {
            return .any
        }

        if uniqueDecls.count == 1, let decl = uniqueDecls.first {
            return decl
        }

        // If we have different single types, the common type is .any
        return .any
    }
}
