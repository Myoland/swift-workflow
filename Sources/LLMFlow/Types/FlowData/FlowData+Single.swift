public extension FlowData {
    // Be simple in the first version.
    enum Single: Sendable {
        case bool(Bool)
        case int(Int) // TODO: Replace by `SignedNumeric` later
        case string(String)
    }

    var single: Single? {
        if case .single(let single) = self {
            return single
        }
        return nil
    }

    var boolValue: Bool? {
        if let single, case .bool(let value) = single {
            return value
        }
        return nil
    }

    var intValue: Int? {
        if let single, case .int(let value) = single {
            return value
        }
        return nil
    }

    var stringValue: String? {
        if let single, case .string(let value) = single {
            return value
        }
        return nil
    }
}

extension FlowData.Single: Hashable {}
