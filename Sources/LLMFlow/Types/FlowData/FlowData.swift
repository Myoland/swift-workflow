
/// A type-erased, serializable data container for use within a ``Workflow``.
///
/// `FlowData` is an enumeration that can represent a single value, a list of values, or a map (dictionary) of values.
/// It is the primary way that data is passed between nodes in a workflow, ensuring that all data is `Sendable` and `Codable`.
///
/// ## Usage
/// You can create `FlowData` instances using literals, making it easy to define inputs for a workflow:
/// ```swift
/// let stringData: FlowData = "Hello"
/// let intData: FlowData = 123
/// let arrayData: FlowData = ["a", 1, true]
/// let dictData: FlowData = ["key1": "value", "key2": 42]
/// ```
///
/// - SeeAlso: ``FlowData/Single``, ``FlowData/List``, ``FlowData/Map``
public enum FlowData: Sendable {
    /// A single, primitive value.
    case single(Single)
    /// A list of `FlowData` values.
    case list(List)
    /// A map from string keys to `FlowData` values.
    case map(Map)
}

extension FlowData: Hashable {}
