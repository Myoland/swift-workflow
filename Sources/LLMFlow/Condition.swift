//
//  Node+swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

// MARK: ConditionNode + OP
public indirect enum Condition: Sendable {
    case and([Condition])
    case or([Condition])
    case not(Condition)
    
    case string(StringEval)
    case int(IntEval)
}

// MARK: ConditionNode.OP + Eval

extension Condition {
    public enum StringEval: Sendable {
        case equal(variable: NodeVariableKey, value: String)
        case empty(variable: NodeVariableKey)
        case contains(variable: NodeVariableKey, value: String, position: StringContainingPosition)
    }
    
    public enum IntEval: Sendable {
        case equal(variable: NodeVariableKey, value: Int)
        case greater(variable: NodeVariableKey, value: Int)
        case greater_or_equal(variable: NodeVariableKey, value: Int)
        case smaller(variable: NodeVariableKey, value: Int)
        case smaller_or_equal(variable: NodeVariableKey, value: Int)
    }
}

// MARK: ConditionNode.OP.StringEval + Postion

extension Condition.StringEval {
    public enum StringContainingPosition: String, Sendable {
        case prefix
        case suffix
        case `default`
    }
}

extension Condition.StringEval: Hashable {}

extension Condition.IntEval: Hashable {}

extension Condition: Hashable {}




protocol Evaluatable {
    func eval(_ context: Context) -> Bool
}

extension Condition: Evaluatable {
    func eval(_ context: Context) -> Bool {
        switch self {
        case .and(let andCondition):
            return andCondition.allSatisfy { $0.eval(context) }
        case .or(let orCondition):
            return orCondition.contains { $0.eval(context) }
        case .not(let notCondition):
            return !notCondition.eval(context)
        case .string(let stringEval):
            return stringEval.eval(context)
        case .int(let intEval):
            return intEval.eval(context)
        }
    }
}

extension Condition.IntEval: Evaluatable {
    func eval(_ context: Context) -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            return context.store[variableKey]?.intValue == value
        case .greater(let variableKey, let value):
            guard let variable = context.store[variableKey]?.intValue else {
                return false
            }
            return variable > value
        case .greater_or_equal(let variableKey, let value):
            guard let variable = context.store[variableKey]?.intValue else {
                return false
            }
            return variable >= value
        case .smaller(let variableKey, let value):
            guard let variable = context.store[variableKey]?.intValue else {
                return false
            }
            return variable < value
        case .smaller_or_equal(let variableKey, let value):
            guard let variable = context.store[variableKey]?.intValue else {
                return false
            }
            return variable <= value
        }
    }
}


extension Condition.StringEval: Evaluatable {
    func eval(_ context: Context) -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            return context.store[variableKey]?.stringValue == value
        case .empty(let variableKey):
            guard let variable = context.store[variableKey]?.stringValue else {
                return false
            }
            return variable.isEmpty
        case .contains(let variableKey, let value, let position):
            guard let variable = context.store[variableKey]?.stringValue else {
                return false
            }
            
            switch position {
            case .default:
                return variable.contains(value)
            case .prefix:
                return variable.hasPrefix(value)
            case .suffix:
                return variable.hasSuffix(value)
            }
        }
    }
}
