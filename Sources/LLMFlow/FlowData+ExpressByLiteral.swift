extension FlowData.Single: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension FlowData.Single: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension FlowData.List: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: FlowData...) {
        self.init(elements: elements.map({ $0 }))
    }
}

extension FlowData.Map: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, FlowData)...) {
        self.init(elements: .init(uniqueKeysWithValues: elements))
    }
}

extension FlowData: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .single(.int(value))
    }
}

extension FlowData: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .single(.string(value))
    }
}

extension FlowData: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: FlowData...) {
        self = .list(.init(elements: elements))
    }
}

extension FlowData: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, FlowData)...) {
        self = .map(.init(elements: .init(uniqueKeysWithValues: elements)))
    }
}
