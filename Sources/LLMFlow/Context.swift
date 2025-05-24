import WantLazy

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
    public typealias Key = String
    public typealias Value = Any
    public typealias Variable = (key: Key, value: Value)

    public typealias Store = [Key: Any]

    private let clientLastEventId: LazyLock<String?> = .init(nil)

    var states: [State] = []
    var store: LazyLock<Store> = .init([:])
    var locator: StoreLocator?

    public init(locater: StoreLocator? = nil) {
        self.locator = locater
    }

    public mutating func update(_ variable: Variable) {
        store.withLock { store in
            store[variable.key] = variable.value
        }
    }

    public mutating func update(key: Key, value: Value) {
        store.withLock { store in
            store[key] = value
        }
    }
    
    public func get(key: Key) -> Value? {
        store.withLock { store in
            store[key]
        }
    }
    
    public func filter(keys: [Key]?) -> [Key: Value] {
        guard let keys else {
            return store.withLock { $0 }
        }
        
        return store.withLock { store in
            store.filter { keys.contains($0.key) }
        }
    }

    public func get<T>(key: Key, as type: T.Type) -> T? {
        store.withLock { store in
            store[key] as? T
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
