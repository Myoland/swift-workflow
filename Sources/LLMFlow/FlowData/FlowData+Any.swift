//
//  FlowData+Jinja.swift
//  dify-forward
//
//  Created on 2025/3/27.
//

import Foundation

extension FlowData {
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
    public var asAny: [Context.Value] {
        self.elements.map { $0.asAny }
    }
}

extension FlowData.Map {
    public var asAny: [String: Context.Value] {
        self.elememts.mapValues { $0.asAny }
    }
}

extension Collection where Element == FlowData {
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
    
    public var asAny: [Key: Context.Value] {
        return self.compactMapValues { $0.asAny }
    }
    
    public func compactMapValuesAsString() -> [Key : String] {
        compactMapValuesAs()
    }
    
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
