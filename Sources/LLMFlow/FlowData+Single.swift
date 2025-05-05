extension FlowData {
    // Be simple in the first version.
    public enum Single: Sendable {
        case bool(Bool)
        case int(Int)  // TODO: Replace by `SignedNumeric` later
        case string(String)
    }

    public var single: Single? {
        if case let .single(single) = self {
            return single
        }
        return nil
    }

    public var boolValue: Bool? {
        if let single, case let .bool(value) = single {
            return value
        }
        return nil
    }
    
    public var intValue: Int? {
        if let single, case let .int(value) = single {
            return value
        }
        return nil
    }

    public var stringValue: String? {
        if let single, case let .string(value) = single {
            return value
        }
        return nil
    }
}

extension FlowData.Single: Hashable {}
