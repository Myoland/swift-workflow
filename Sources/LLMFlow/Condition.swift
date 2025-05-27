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
        case equal(variable: String, value: String)
        case empty(variable: String)
        case contains(variable: String, value: String, position: StringContainingPosition)
    }
    
    public enum IntEval: Sendable {
        case equal(variable: String, value: Int)
        case greater(variable: String, value: Int)
        case greater_or_equal(variable: String, value: Int)
        case smaller(variable: String, value: Int)
        case smaller_or_equal(variable: String, value: Int)
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
    func eval(_ context: [String: Any]) -> Bool
}

extension Condition: Evaluatable {
    func eval(_ context: [String: Any]) -> Bool {
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
    func eval(_ inputs: [String: Any]) -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let intValue: Int = if let variable = variable as? Int {
                variable
            } else if let variable = (variable as? FlowData)?.intValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            return intValue == value
        case .greater(let variableKey, let value):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let intValue: Int = if let variable = variable as? Int {
                variable
            } else if let variable = (variable as? FlowData)?.intValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            return intValue > value
        case .greater_or_equal(let variableKey, let value):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let intValue = if let variable = variable as? Int {
                variable
            } else if let variable = (variable as? FlowData)?.intValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            
            return intValue >= value
        case .smaller(let variableKey, let value):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let intValue = if let variable = variable as? Int {
                variable
            } else if let variable = (variable as? FlowData)?.intValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            
            return intValue < value
        case .smaller_or_equal(let variableKey, let value):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let intValue = if let variable = variable as? Int {
                variable
            } else if let variable = (variable as? FlowData)?.intValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            
            return intValue <= value
        }
    }
}


extension Condition.StringEval: Evaluatable {
    func eval(_ inputs: [String: Any]) -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let stringValue = if let variable = variable as? String {
                variable
            } else if let variable = (variable as? FlowData)?.stringValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            return stringValue == value
        case .empty(let variableKey):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let stringValue = if let variable = variable as? String {
                variable
            } else if let variable = (variable as? FlowData)?.stringValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            return stringValue.isEmpty
        case .contains(let variableKey, let value, let position):
            guard let variable = inputs[variableKey] else {
                return false
            }
            
            guard let stringValue = if let variable = variable as? String {
                variable
            } else if let variable = (variable as? FlowData)?.stringValue {
                variable
            } else {
                nil
            } else {
                return false
            }
            
            switch position {
            case .default:
                return stringValue.contains(value)
            case .prefix:
                return stringValue.hasPrefix(value)
            case .suffix:
                return stringValue.hasSuffix(value)
            }
        }
    }
}
