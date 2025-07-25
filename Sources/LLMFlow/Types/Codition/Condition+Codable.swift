//
//  Condition+Codable.swift
//  dify-forward
//
//  Created by AFuture on 2025/3/18.
//

// MARK: ConditionNode.OP.StringEval + Hashable & Codable

extension Condition.StringEval: Codable {
    
    public enum CodingKeys: String, CodingKey {
        case equal
        case empty
        case contains
    }
    
    public enum NestedCodingKeys: CodingKey {
        case variable
        case value
        case position
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = container.allKeys
        
        guard !keys.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No Key Found"))
        }
        
        guard keys.count == 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Too Many Keys"))
        }
        
        let key = keys.first!
        switch key {
        case .empty:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .empty)
            let variable = try nested.decode(String.self, forKey: .variable)
            self = .empty(variable: variable)
        case .equal:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .equal)
            let variable = try nested.decode(String.self, forKey: .variable)
            let value = try nested.decode(String.self, forKey: .value)
            self = .equal(variable: variable, value: value)
        case .contains:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .contains)
            let variable = try nested.decode(String.self, forKey: .variable)
            let value = try nested.decode(String.self, forKey: .value)
            if let positionRawValue = try nested.decodeIfPresent(String.self, forKey: .position) {
                if let position = StringContainingPosition(rawValue: positionRawValue) {
                    self = .contains(variable: variable, value: value, position: position)
                } else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.contains, NestedCodingKeys.position], debugDescription: "Position value is invalid"))
                }
            } else {
                self = .contains(variable: variable, value: value, position: .default)
            }
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .equal(let variable, let value):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .equal)
            try body.encode(variable, forKey: .variable)
            try body.encode(value, forKey: .value)
        case .empty(let variable):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .empty)
            try body.encode(variable, forKey: .variable)
        case .contains(let variable, let value, let position):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .contains)
            try body.encode(variable, forKey: .variable)
            try body.encode(value, forKey: .value)
            try body.encode(position.rawValue, forKey: .position)
        }
    }
}

// MARK: ConditionNode.OP.IntEval + Hashable & Codable

extension Condition.IntEval: Codable {
    
    public enum CodingKeys: String, CodingKey {
        case equal
        case greater
        case greater_or_equal
        case smaller
        case smaller_or_equal
    }
    
    public enum NestedCodingKeys: CodingKey {
        case variable
        case value
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = container.allKeys
        
        guard !keys.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No Key Found"))
        }
        
        guard keys.count == 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Too Many Keys"))
        }
        
        let key = keys.first!
        switch key {
        case .equal:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .equal)
            let variable = try nested.decode(String.self, forKey: .variable)
            let value = try nested.decode(Int.self, forKey: .value)
            self = .equal(variable: variable, value: value)
        case .greater:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .greater)
            let variable = try nested.decode(String.self, forKey: .variable)
            let value = try nested.decode(Int.self, forKey: .value)
            self = .greater(variable: variable, value: value)
        case .greater_or_equal:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .greater_or_equal)
            let variable = try nested.decode(String.self, forKey: .variable)
            let value = try nested.decode(Int.self, forKey: .value)
            self = .greater_or_equal(variable: variable, value: value)
        case .smaller:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .smaller)
            let variable = try nested.decode(String.self, forKey: .variable)
            let value = try nested.decode(Int.self, forKey: .value)
            self = .smaller(variable: variable, value: value)
        case .smaller_or_equal:
            let nested = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .smaller_or_equal)
            let variable = try nested.decode(String.self, forKey: .variable)
            let value = try nested.decode(Int.self, forKey: .value)
            self = .smaller_or_equal(variable: variable, value: value)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .equal(let variable, let value):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .equal)
            try body.encode(variable, forKey: .variable)
            try body.encode(value, forKey: .value)
        case .greater(let variable, let value):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .greater)
            try body.encode(variable, forKey: .variable)
            try body.encode(value, forKey: .value)
        case .greater_or_equal(let variable, let value):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .greater_or_equal)
            try body.encode(variable, forKey: .variable)
            try body.encode(value, forKey: .value)
        case .smaller(let variable, let value):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .smaller)
            try body.encode(variable, forKey: .variable)
            try body.encode(value, forKey: .value)
        case .smaller_or_equal(let variable, let value):
            var body = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .smaller_or_equal)
            try body.encode(variable, forKey: .variable)
            try body.encode(value, forKey: .value)
        }
    }
}

// MARK: ConditionNode.OP + Hashable & Codable

extension Condition: Codable {
    
    public enum CodingKeys: String, CodingKey {
        case and
        case or
        case not
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keys = container.allKeys
        
        guard keys.count <= 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Too Many Keys"))
        }
        
        if keys.isEmpty {
            let container = try decoder.singleValueContainer()
            if let evel = try? container.decode(IntEval.self) {
                self = .int(evel)
            } else if let evel = try? container.decode(StringEval.self) {
                self = .string(evel)
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No Eval Object Found"))
            }
        } else {
            let key = keys.first!
            switch key {
            case .and:
                var nested = try container.nestedUnkeyedContainer(forKey: .and)
                var ops: [Self] = []
                while !nested.isAtEnd {
                    try ops.append(nested.decode(Self.self))
                }
                self = .and(ops)
            case .or:
                var nested = try container.nestedUnkeyedContainer(forKey: .or)
                var ops: [Self] = []
                while !nested.isAtEnd {
                    try ops.append(nested.decode(Self.self))
                }
                self = .or(ops)
            case .not:
                let op = try container.decode(Self.self, forKey: .not)
                self = .not(op)
            }
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case let .and(ops):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ops, forKey: .and)
        case let .or(ops):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ops, forKey: .or)
        case let .not(op):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(op, forKey: .not)
        case let .string(eval):
            var container = encoder.singleValueContainer()
            try container.encode(eval)
        case let .int(eval):
            var container = encoder.singleValueContainer()
            try container.encode(eval)
        }
    }
}
