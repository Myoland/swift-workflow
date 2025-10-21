//
//  Node+swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//

// MARK: ConditionNode + OP

/// Represents a condition that can be evaluated to control the flow of a ``Workflow``.
///
/// Conditions are attached to ``Workflow/Edge``s and determine whether a particular path can be taken.
/// They can be combined using logical operators (`and`, `or`, `not`) and can perform evaluations
/// on string and integer values retrieved from the workflow's ``Context``.
///
/// ## Example
/// A condition that checks if a context variable `user_input` contains the word "question":
/// ```swift
/// let condition = Condition.string(
///     .contains(
///         variable: "user_input",
///         value: "question",
///         position: .default
///     )
/// )
///
/// let context: [String: AnySendable] = ["user_input": "What is the capital of France?"]
/// let result = condition.eval(context) // true
/// ```
public indirect enum Condition: Sendable {
    /// A logical AND operation. All sub-conditions must be true.
    case and([Condition])
    /// A logical OR operation. At least one sub-condition must be true.
    case or([Condition])
    /// A logical NOT operation. The sub-condition must be false.
    case not(Condition)

    /// A condition that evaluates a string value.
    case string(StringEval)
    /// A condition that evaluates an integer value.
    case int(IntEval)
}

// MARK: ConditionNode.OP + Eval

public extension Condition {
    /// A set of evaluation operations for string values.
    enum StringEval: Sendable {
        /// Checks if the string variable is equal to a given value.
        case equal(variable: ContextStorePath, value: String)
        /// Checks if the string variable is empty.
        case empty(variable: ContextStorePath)
        /// Checks if the string variable contains, starts with, or ends with a given substring.
        case contains(variable: ContextStorePath, value: String, position: StringContainingPosition)
    }

    /// A set of evaluation operations for integer values.
    enum IntEval: Sendable {
        /// Checks if the integer variable is equal to a given value.
        case equal(variable: ContextStorePath, value: Int)
        /// Checks if the integer variable is greater than a given value.
        case greater(variable: ContextStorePath, value: Int)
        /// Checks if the integer variable is greater than or equal to a given value.
        case greater_or_equal(variable: ContextStorePath, value: Int)
        /// Checks if the integer variable is less than a given value.
        case smaller(variable: ContextStorePath, value: Int)
        /// Checks if the integer variable is less than or equal to a given value.
        case smaller_or_equal(variable: ContextStorePath, value: Int)
    }
}

// MARK: ConditionNode.OP.StringEval + Postion

public extension Condition.StringEval {
    /// Specifies the position for a substring match in a `contains` evaluation.
    enum StringContainingPosition: String, Sendable {
        /// The string must start with the substring.
        case prefix
        /// The string must end with the substring.
        case suffix
        /// The substring can appear anywhere in the string.
        case `default`
    }
}

extension Condition.StringEval: Hashable {}

extension Condition.IntEval: Hashable {}

extension Condition: Hashable {}

protocol Evaluatable {
    /// Evaluates the condition against a given context.
    /// - Parameter context: The workflow context store.
    /// - Returns: `true` if the condition is met, otherwise `false`.
    func eval(_ context: [String: AnySendable]) -> Bool
}

extension Condition: Evaluatable {
    /// Evaluates the condition against a given context.
    /// - Parameter context: The workflow context store.
    /// - Returns: `true` if the condition is met, otherwise `false`.
    public func eval(_ context: [String: AnySendable]) -> Bool {
        switch self {
        case .and(let andCondition):
            andCondition.allSatisfy { $0.eval(context) }
        case .or(let orCondition):
            orCondition.contains { $0.eval(context) }
        case .not(let notCondition):
            !notCondition.eval(context)
        case .string(let stringEval):
            stringEval.eval(context)
        case .int(let intEval):
            intEval.eval(context)
        }
    }
}

extension Condition.IntEval: Evaluatable {
    func eval(_ inputs: [String: AnySendable]) -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            guard let variable = inputs[path: variableKey] else {
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
            guard let variable = inputs[path: variableKey] else {
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
            guard let variable = inputs[path: variableKey] else {
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
            guard let variable = inputs[path: variableKey] else {
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
            guard let variable = inputs[path: variableKey] else {
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
    func eval(_ inputs: [String: AnySendable]) -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            guard let variable = inputs[path: variableKey] else {
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
            guard let variable = inputs[path: variableKey] else {
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
            guard let variable = inputs[path: variableKey] else {
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
