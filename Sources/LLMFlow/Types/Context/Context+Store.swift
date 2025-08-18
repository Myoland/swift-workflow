//
//  Context+Store.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-18.
//


public struct ContextStorePath: Hashable, Sendable {
    public struct Key: Hashable, Sendable {
        let strValue: String
        let intValue: Int?
        
        public init(strValue: String) {
            if let intValue = Int(strValue) {
                self.init(strValue: strValue, intValue: intValue)
            } else {
                self.init(strValue: strValue, intValue: nil)
            }
        }
        
        public init(intValue: Int) {
            self.init(strValue: "\(intValue)", intValue: intValue)
        }
        
        init(strValue: String, intValue: Int?) {
            self.strValue = strValue
            self.intValue = intValue
        }
    }
    
    let keys: [Key]
    
    public init(keys: [Key]) {
        self.keys = keys
    }
}

extension ContextStorePath: CustomStringConvertible {
    public var description: String {
        self.keys.map(\.strValue).joined(separator: ".")
    }
}

extension ContextStorePath: LosslessStringConvertible {
    public init(_ description: String) {
        let keys = description.split(separator: ".").map { ContextStorePath.Key(strValue: String($0)) }
        self.init(keys: keys)
    }
}

extension ContextStorePath: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(raw)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}


extension ContextStorePath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension ContextStorePath: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(keys: [.init(intValue: value)])
    }
}
extension ContextStorePath.Key: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(strValue: value)
    }
}

extension ContextStorePath.Key: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(intValue: value)
    }
}

extension ContextStorePath: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: ContextStorePath.Key...) {
        self.init(keys: elements)
    }
}


// MARK: Collection

extension Collection where Element == AnySendable, Index == Int {
    subscript(key position: ContextStorePath.Key?) -> Element? {
        guard let idx = position?.intValue else {
            return nil
        }
        return self[idx]
    }
    
    subscript(path path: ContextStorePath?) -> Element? {
        guard let keys = path?.keys else { return nil }
        
        let (key, rest) = keys.separateFirst()
        
        guard let value = self[key: key] else {
            return nil
        }
        
        guard let rest, !rest.isEmpty else {
            return value
        }
        
        if let dic = value as? [String: Element] {
            return dic[path: .init(keys: rest)]
        } else if let list = value as? [Element] {
            return list[path: .init(keys: rest)]
        }
        
        return nil
    }
}

extension MutableCollection where Element == AnySendable, Index == Int {
    subscript(key position: ContextStorePath.Key?) -> Element? {
        get {
            guard let idx = position?.intValue else {
                return nil
            }
            return self[idx]
        }
        set {
            guard let idx = position?.intValue else {
                return
            }
            return self[idx] = newValue
        }
    }
    
    subscript(keys keys: [ContextStorePath.Key]?) -> Element? {
        get {
            guard let keys else { return nil }
            
            let (key, rest) = keys.separateFirst()
            
            guard let value = self[key: key] else {
                return nil
            }
            
            guard let rest, !rest.isEmpty else {
                return value
            }
            
            if let dic = value as? [String: Element] {
                return dic[keys: rest]
            } else if let list = value as? [Element] {
                return list[keys: rest]
            }
            
            return nil
        }

        set {
            guard let keys else { return }
            
            let (key, rest) = keys.separateFirst()
            
            guard let rest, !rest.isEmpty else {
                self[key: key] = newValue
                return
            }
            
            if rest.first?.intValue == nil {
                var dict = self[key: key] as? [String: Element] ?? [:]
                dict[keys: rest] = newValue
                self[key: key] = dict
            } else {
                var list = self[key: key] as? [Element] ?? []
                list[keys: rest] = newValue
                self[key: key] = list
            }
        }
    }
    
    subscript(path path: ContextStorePath?) -> Element? {
        get {
            self[keys: path?.keys]
        }
        
        set {
            self[keys: path?.keys] = newValue
        }
    }
    
}

// MARK: Dictionary

extension Dictionary where Value == AnySendable, Key == String {
    subscript(safe key: Key?) -> Value? {
        get {
            guard let key else { return nil }
            return self[key]
        }
        
        set {
            guard let key else { return }
            self[key] = newValue
        }
    }
    
    subscript(key path: ContextStorePath.Key?) -> Value? {
        get {
            guard let key = path?.strValue, path?.intValue == nil else { return nil }
            return self[key]
        }
        
        set {
            guard let key = path?.strValue, path?.intValue == nil else { return }
            self[key] = newValue
        }
    }
    
    subscript(keys keys: [ContextStorePath.Key]?) -> Value? {
        get {
            guard let keys else { return nil }
            
            let (key, rest) = keys.separateFirst()
            
            guard let value = self[key: key] else {
                return nil
            }
            
            guard let rest, !rest.isEmpty else {
                return value
            }
            
            if let dic = value as? [Key: Value] {
                return dic[path: .init(keys: rest)]
            } else if let list = value as? [Value] {
                return list[path: .init(keys: rest)]
            }
            
            return nil
        }
        
        set {
            guard let keys else { return }
            
            let (key, rest) = keys.separateFirst()
            
            guard let rest, !rest.isEmpty else {
                self[key: key] = newValue
                return
            }
            
            if rest.first?.intValue == nil {
                var dict = self[key: key] as? [String: Value] ?? [:]
                dict[keys: rest] = newValue
                self[key: key] = dict
            } else {
                var list = self[key: key] as? [Value] ?? []
                list[keys: rest] = newValue
                self[key: key] = list
            }
        }
    }
    
    
    subscript(path path: ContextStorePath?) -> Value? {
        get {
            self[keys: path?.keys]
        }
        
        set {
            self[keys: path?.keys] = newValue
        }
    }
    
    subscript(path keys: Key...) -> Value? {
        get {
            self[keys: keys.map {ContextStorePath.Key(strValue: $0)} ]
        }
        
        set {
            self[keys: keys.map {ContextStorePath.Key(strValue: $0)} ] = newValue
        }
    }
    
    subscript(path keys: [Key]?) -> Value? {
        get {
            self[keys: keys?.map { ContextStorePath.Key(strValue: $0, intValue: nil) }]
        }
        
        set {
            self[keys: keys?.map { ContextStorePath.Key(strValue: $0, intValue: nil) }] = newValue
        }
    }
}



extension Collection {
    fileprivate func separateFirst() -> (Element?, [Element]?) {
        (self.first, Array(self.dropFirst()))
    }
}
