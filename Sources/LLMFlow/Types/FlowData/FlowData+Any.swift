//
//  FlowData+Any.swift
//  dify-forward
//
//  Created on 2025/3/27.
//

import Foundation

public extension FlowData {
    /// Converts the `FlowData` instance to a native Swift type (`AnySendable`).
    ///
    /// This property recursively unwraps the `FlowData` enum into its corresponding Swift type:
    /// - `.single` becomes a `Bool`, `Int`, or `String`.
    /// - `.list` becomes an `[AnySendable]`.
    /// - `.map` becomes a `[String: AnySendable]`.
    ///
    /// This is useful for when you need to interact with the underlying data in a type-safe manner
    /// after retrieving it from the ``Context``.
    var asAny: Context.Value {
        switch self {
        case .single(let single):
            single.asAny
        case .list(let list):
            list.asAny
        case .map(let map):
            map.asAny
        }
    }
}

public extension FlowData.Single {
    /// Converts the `Single` value to its native Swift type.
    var asAny: Context.Value {
        switch self {
        case .bool(let value):
            value
        case .int(let value):
            value
        case .string(let value):
            value
        }
    }
}

public extension FlowData.List {
    /// Converts the `List` to an array of native Swift types.
    var asAny: [Context.Value] {
        elements.map(\.asAny)
    }
}

public extension FlowData.Map {
    /// Converts the `Map` to a dictionary of native Swift types.
    var asAny: [String: Context.Value] {
        elememts.mapValues { $0.asAny }
    }
}

public extension Collection<FlowData> {
    /// Converts a collection of `FlowData` to an array of native Swift types.
    var asAny: [Any] {
        compactMap(\.asAny)
    }
}

public extension Dictionary where Value == FlowData {
    internal subscript(key: Key?) -> Value? {
        guard let key else {
            return nil
        }
        return self[key]
    }

    /// Converts a dictionary with `FlowData` values to a dictionary with native Swift types.
    var asAny: [Key: Context.Value] {
        compactMapValues { $0.asAny }
    }

    /// Converts the dictionary's values to `String`, filtering out any that are not strings.
    func compactMapValuesAsString() -> [Key: String] {
        compactMapValuesAs()
    }

    /// Converts the dictionary's values to a specific type `T`, filtering out any that do not match.
    func compactMapValuesAs<T>(type _: T.Type = T.self) -> [Key: T] {
        compactMapValues { $0.asAny as? T }
    }
}

extension Dictionary where Key: Equatable {
    func extract(_ keys: [Key]?) -> [Key: Value] {
        filter { key, _ in
            keys?.contains(key) ?? false
        }
    }
}

extension Dictionary {
    func convertKeys<T>(tansfomer: (Key) -> T) -> [T: Value] {
        reduce(into: .init()) { partialResult, pair in
            partialResult.updateValue(pair.value, forKey: tansfomer(pair.key))
        }
    }
}
