extension FlowData: CustomStringConvertible {
    public var description: String {
        switch self {
        case .single(let single):
            single.description
        case .list(let list):
            list.description
        case .map(let map):
            map.description
        }
    }
}

extension FlowData.Single: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bool(let value):
            value ? "true" : "false"
        case .int(let value):
            "\(value)"
        case .string(let value):
            value
        }
    }
}

extension FlowData.List: CustomStringConvertible {
    public var description: String {
        elements.description
    }
}

extension FlowData.Map: CustomStringConvertible {
    public var description: String {
        elememts.description
    }
}
