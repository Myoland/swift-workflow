extension FlowData.Single: Codable {
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
                    debugDescription: "Only Support String and Int."))
        }
    }

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
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let elements = try container.decode([FlowData].self)

        self.elements = elements
        self.elemDecl = elements.decl
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(elements)
    }
}

extension FlowData.Map: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let values = try container.decode([String: FlowData].self)

        self.elememts = values
        self.elemDecl = values.values.decl
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(elememts)
    }
}

extension FlowData: Codable {

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
                .init(codingPath: container.codingPath, debugDescription: "")  // TODO:
            )
        }
    }

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
