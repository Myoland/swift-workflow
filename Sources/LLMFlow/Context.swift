import LazyKit

public typealias AnySendable = Any & Sendable


extension Context {
    struct State: Sendable {

    }
}


public protocol AnyStorageValue: Sendable {}

public protocol StoreLocator: AnyStorageValue {
    func resolve<T>(shared type: T.Type) -> T?
    func resolve<K, T>(for key: K.Type, as type: T.Type) -> T?
}

public typealias DataKeyPaths = [DataKeyPath]
public typealias DataKeyPath = String

public struct Context: Sendable {
    public typealias Key = DataKeyPath
    public typealias Value = AnySendable
    
    public typealias Store = [Key: Value]
    
    private let clientLastEventId: LazyLock<String?> = .init(nil)
    
    var states: [State] = []
    var store: LazyLock<Store> = .init([:])
    var locator: StoreLocator?
    
    public init(locater: StoreLocator? = nil) {
        self.locator = locater
    }
    
}

extension Context {
    subscript(key: Key?) -> Value? {
        get {
            let a = store.withLock { store in
                store[safe: key]
            }
            return a
        }
        
        set {
            store.withLock { store in
                store[safe: key] = newValue
            }
        }
    }
    
    subscript<T>(safe key: Key?, as type: T.Type = T.self) -> T? {
        get {
            store.withLock { store in
                store[safe: key] as? T
            }
        }
    }
    
    subscript(path keys: Key...) -> Value? {
        get {
            self[path: keys]
        }
        
        set {
            self[path: keys] = newValue
        }
    }
    
    subscript(path keys: [Key]?) -> Value? {
        get {
            store.withLock { store in
                store[path: keys]
            }
        }
        
        set {
            store.withLock { store in
                store[path: keys] = newValue
            }
        }
    }
}

extension Context {
    public func filter(keys: [Key]?) -> [Key: Value] {
        guard let keys else {
            return store.withLock { $0 }
        }
        
        return store.withLock { store in
            store.filter { keys.contains($0.key) }
        }
    }
    
    public func filter<T>(keys: [Key]?, as type: T.Type) ->  [Key: T]  {
        guard let keys else {
            return store.withLock { $0.compactMapValues { $0 as? T } }
        }
        
        return store.withLock { store in
            store.filter { keys.contains($0.key) }.compactMapValues { $0 as? T }
        }
    }
}


// [2025/06/02 <Huanan>] TODO: Support Collection
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
    
    subscript(path keys: Key...) -> Value? {
        get {
            self[path: keys]
        }
        
        set {
            self[path: keys] = newValue
        }
    }
    
    subscript(path keys: [Key]?) -> Value? {
        get {
            guard let keys else { return nil }
            
            let (key, rest) = keys.separateFirst()
            
            guard let value = self[safe: key] else {
                return nil
            }
            
            guard let rest, !rest.isEmpty else {
                return value
            }
            
            guard let value = value as? [Key: Value] else {
                return nil
            }
            
            return value[path: rest]
        }
        
        set {
            guard let keys else { return }
            // guard let newValue else { return }
            
            let (key, rest) = keys.separateFirst()
            
            guard let rest, !rest.isEmpty else {
                self[safe: key] = newValue
                return
            }
            
            guard var value = self[safe: key] as? [Key: Value] else {
                return
            }
            
            value[path: rest] = newValue
            
            self[safe: key] = value
        }
    }
}

extension Collection {
    func separateFirst() -> (Element?, [Element]?) {
        (self.first, Array(self.dropFirst()))
    }
}
