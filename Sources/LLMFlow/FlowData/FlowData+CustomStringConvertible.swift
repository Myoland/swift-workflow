extension FlowData: CustomStringConvertible {
    public var description: String {
        switch self {
        case .single(let single):
            return single.description
        case .list(let list):
            return list.description
        case .map(let map):
            return map.description
        }
    }
}


extension FlowData.Single: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bool(let value):
            return value ? "true" : "false"
        case .int(let value):
            return "\(value)"
        case .string(let value):
            return value
        }
    }
}

extension FlowData.List: CustomStringConvertible {
    public var description: String {
        return elements.description
    }
}

extension FlowData.Map: CustomStringConvertible {
    public var description: String {
        return elememts.description
    }
}
