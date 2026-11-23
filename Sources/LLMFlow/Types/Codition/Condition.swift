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
    /// - Throws: ``ContextStorePath/IndexOutOfRangeError`` if a variable indexes past the end of a list.
    func evaluate(_ context: [String: AnySendable]) throws -> Bool
}

extension Condition: Evaluatable {
    /// Evaluates the condition against a given context, as the engine does when it picks the next edge.
    ///
    /// A variable that is missing, or whose value has another type, makes its comparison `false`.
    ///
    /// - Parameter context: The workflow context store.
    /// - Returns: `true` if the condition is met, otherwise `false`.
    /// - Throws: ``ContextStorePath/IndexOutOfRangeError`` if a variable indexes past the end of a list
    ///   (or before its start).
    public func evaluate(_ context: [String: AnySendable]) throws -> Bool {
        switch self {
        case .and(let andCondition):
            try andCondition.allSatisfy { try $0.evaluate(context) }
        case .or(let orCondition):
            try orCondition.contains { try $0.evaluate(context) }
        case .not(let notCondition):
            try !notCondition.evaluate(context)
        case .string(let stringEval):
            try stringEval.evaluate(context)
        case .int(let intEval):
            try intEval.evaluate(context)
        }
    }

    /// Evaluates the condition against a given context.
    /// - Parameter context: The workflow context store.
    /// - Returns: `true` if the condition is met, otherwise `false` (also when ``evaluate(_:)`` throws).
    public func eval(_ context: [String: AnySendable]) -> Bool {
        (try? evaluate(context)) ?? false
    }
}

// MARK: Condition + Static Analysis

public extension Condition {
    /// The Boolean result when evaluation succeeds without reading the context: `true` or `false` when it does not
    /// depend on any variable (`and: []` always holds, `or: []` never does), `nil` when it depends on the context.
    ///
    /// Evaluation still reads the sub-conditions before the one that decides, so it can throw: `and: [<reads a list
    /// out of range>, or: []]` has the constant value `false`, but ``evaluate(_:)`` throws
    /// ``ContextStorePath/IndexOutOfRangeError``.
    var constantValue: Bool? {
        switch self {
        case .and(let conditions):
            let values = conditions.map(\.constantValue)
            return values.contains(false) ? false : values.allSatisfy { $0 == true } ? true : nil
        case .or(let conditions):
            let values = conditions.map(\.constantValue)
            return values.contains(true) ? true : values.allSatisfy { $0 == false } ? false : nil
        case .not(let condition):
            return condition.constantValue.map { !$0 }
        case .string, .int:
            return nil
        }
    }

    /// The variables the condition reads, in order.
    internal var variables: [ContextStorePath] {
        switch self {
        case .and(let conditions), .or(let conditions):
            conditions.flatMap(\.variables)
        case .not(let condition):
            condition.variables
        case .string(.equal(let variable, _)), .string(.empty(let variable)), .string(.contains(let variable, _, _)),
             .int(.equal(let variable, _)), .int(.greater(let variable, _)), .int(.greater_or_equal(let variable, _)),
             .int(.smaller(let variable, _)), .int(.smaller_or_equal(let variable, _)):
            [variable]
        }
    }

    /// Whether one of `conditions` holds whatever the context: one is `nil` (an edge without a condition),
    /// one always holds (``constantValue`` is `true`), or one is the `not` of another.
    static func isExhaustive(_ conditions: [Condition?]) -> Bool {
        conditions.contains { condition in
            guard let condition else { return true }
            return condition.constantValue == true || conditions.contains(.not(condition))
        }
    }
}

extension Condition.IntEval: Evaluatable {
    func evaluate(_ inputs: [String: AnySendable]) throws -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            guard let variable = try variableKey.lookup(in: inputs) else {
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
            guard let variable = try variableKey.lookup(in: inputs) else {
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
            guard let variable = try variableKey.lookup(in: inputs) else {
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
            guard let variable = try variableKey.lookup(in: inputs) else {
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
            guard let variable = try variableKey.lookup(in: inputs) else {
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
    func evaluate(_ inputs: [String: AnySendable]) throws -> Bool {
        switch self {
        case .equal(let variableKey, let value):
            guard let variable = try variableKey.lookup(in: inputs) else {
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
            guard let variable = try variableKey.lookup(in: inputs) else {
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
            guard let variable = try variableKey.lookup(in: inputs) else {
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
