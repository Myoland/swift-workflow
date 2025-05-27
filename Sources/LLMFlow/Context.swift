import LazyKit

struct Schema: Codable {}

extension Context {
    struct State: Sendable {

    }
}


public protocol AnyStorageValue: Sendable {}

public protocol StoreLocator: AnyStorageValue {
    func resolve<T>(shared type: T.Type) -> T?
    func resolve<K, T>(for key: K.Type, as type: T.Type) -> T?
}

public struct Context: Sendable {
    public typealias Key = DataKeyPath
    public typealias Value = Any
    
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
    public func get(key: DataKeyPath) -> Value? {
        store.withLock { store in
            store[key]
        }
    }
    
    public func get(keyPath: DataKeyPaths) -> Value? {
        store.withLock { store in
            var value: Value?
            for key in keyPath {
                value = store[key]
            }
            return value
        }
    }
    
    public func get<T>(key: Key, as type: T.Type) -> T? {
        store.withLock { store in
            store[key] as? T
        }
    }
    
    public func get<T>(keyPath: DataKeyPaths, as type: T.Type) -> Value? {
        store.withLock { store in
            var value: Value?
            for key in keyPath {
                value = store[key]
            }
            return value as? T
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

extension Context {
    public mutating func update(key: Key, value: Value) {
        store.withLock { store in
            store[key] = value
        }
    }
    
    public mutating func update(keyPath: DataKeyPaths, value: Value) {
        var keyPath = keyPath
        guard let lastKey = keyPath.popLast() else {
            return
        }
        
        store.withLock { store in
            var value: Value?
            for key in keyPath {
                value = store[key]
            }
            
            store[lastKey] = value
        }
    }
}
