extension FlowData.Single: Codable {
    /// Decodes a `Single` value from a single-value container.
    ///
    /// It attempts to decode the value as a `Bool`, `Int`, or `String`, in that order.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.typeMismatch(
                FlowData.Single.self,
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Only Support String, Int, and Bool."))
        }
    }

    /// Encodes the `Single` value into a single-value container.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

extension FlowData.List: Codable {
    /// Decodes a `List` from a single-value container holding an array of `FlowData`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let elements = try container.decode([FlowData].self)

        self.elements = elements
        self.elemDecl = elements.decl
    }

    /// Encodes the `List`'s elements into a single-value container.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(elements)
    }
}

extension FlowData.Map: Codable {
    /// Decodes a `Map` from a single-value container holding a dictionary of `[String: FlowData]`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let values = try container.decode([String: FlowData].self)

        self.elememts = values
        self.elemDecl = values.values.decl
    }

    /// Encodes the `Map`'s elements into a single-value container.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(elememts)
    }
}

extension FlowData: Codable {

    /// Decodes a `FlowData` instance by attempting to decode it as a single value, a list, or a map.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let single = try? container.decode(FlowData.Single.self) {
            self = .single(single)
        } else if let list = try? container.decode(FlowData.List.self) {
            self = .list(list)
        } else if let map = try? container.decode(FlowData.Map.self) {
            self = .map(map)
        } else {
            throw DecodingError.typeMismatch(
                FlowData.self,
                .init(codingPath: container.codingPath, debugDescription: "Could not decode FlowData as single, list, or map.")
            )
        }
    }

    /// Encodes the `FlowData` instance into the appropriate container based on its case.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .single(let single):
            try container.encode(single)
        case .list(let list):
            try container.encode(list)
        case .map(let map):
            try container.encode(map)
        }
    }

}
