//
//  FlowData+Jinja.swift
//  dify-forward
//
//  Created on 2025/3/27.
//

import Foundation

extension FlowData {
    public var asAny: Any {
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
    public var asAny: Any {
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
    public var asAny: [Any] {
        self.elements.map { $0.asAny }
    }
}

extension FlowData.Map {
    public var asAny: [String: Any] {
        self.elememts.mapValues { $0.asAny }
    }
}

extension Collection where Element == FlowData {
    public var asAny: [Any] {
        return self.compactMap { $0.asAny }
    }
}

extension Dictionary where Key == String, Value == FlowData {
    subscript(key: Key?) -> Value? {
        get {
            guard let key else {
                return nil
            }
            return self[key]
        }
    }
    
    public var asAny: [String: Any] {
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
    func mapKeys(keys: [Key: Key]) -> Dictionary<Key, Value> {
        var reuslt: [Key: Value] = [:]
        for (to, from) in keys {
            reuslt[to] = self[from]
        }
        return reuslt
    }
}
