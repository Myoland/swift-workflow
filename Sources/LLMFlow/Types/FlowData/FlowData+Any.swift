//
//  FlowData+Jinja.swift
//  dify-forward
//
//  Created on 2025/3/27.
//

import Foundation

extension FlowData {
    /// Converts the `FlowData` instance to a native Swift type (`AnySendable`).
    ///
    /// This property recursively unwraps the `FlowData` enum into its corresponding Swift type:
    /// - `.single` becomes a `Bool`, `Int`, or `String`.
    /// - `.list` becomes an `[AnySendable]`.
    /// - `.map` becomes a `[String: AnySendable]`.
    ///
    /// This is useful for when you need to interact with the underlying data in a type-safe manner
    /// after retrieving it from the ``Context``.
    public var asAny: Context.Value {
        switch self {
        case .single(let single):
            return single.asAny
        case .list(let list):
            return list.asAny
        case .map(let map):
            return map.asAny
        }
    }
}

extension FlowData.Single {
    /// Converts the `Single` value to its native Swift type.
    public var asAny: Context.Value {
        switch self {
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .string(let value):
            return value
        }
    }
}

extension FlowData.List {
    /// Converts the `List` to an array of native Swift types.
    public var asAny: [Context.Value] {
        self.elements.map { $0.asAny }
    }
}

extension FlowData.Map {
    /// Converts the `Map` to a dictionary of native Swift types.
    public var asAny: [String: Context.Value] {
        self.elememts.mapValues { $0.asAny }
    }
}

extension Collection where Element == FlowData {
    /// Converts a collection of `FlowData` to an array of native Swift types.
    public var asAny: [Any] {
        return self.compactMap { $0.asAny }
    }
}

extension Dictionary where Value == FlowData {
    subscript(key: Key?) -> Value? {
        get {
            guard let key else {
                return nil
            }
            return self[key]
        }
    }
    
    /// Converts a dictionary with `FlowData` values to a dictionary with native Swift types.
    public var asAny: [Key: Context.Value] {
        return self.compactMapValues { $0.asAny }
    }
    
    /// Converts the dictionary's values to `String`, filtering out any that are not strings.
    public func compactMapValuesAsString() -> [Key : String] {
        compactMapValuesAs()
    }
    
    /// Converts the dictionary's values to a specific type `T`, filtering out any that do not match.
    public func compactMapValuesAs<T>(type: T.Type = T.self) -> [Key : T] {
        compactMapValues { $0.asAny as? T }
    }
}

extension Dictionary where Key: Equatable {
    func extract(_ keys: [Key]?) -> Dictionary<Key, Value> {
        filter { key, _ in
            keys?.contains(key) ?? false
        }
    }
}

extension Dictionary {
    func convertKeys<T>(tansfomer: (Key) -> T) -> Dictionary<T, Value> {
        self.reduce(into: .init()) { (partialResult, pair) -> () in
            partialResult.updateValue(pair.value, forKey: tansfomer(pair.key))
        }
    }
}
