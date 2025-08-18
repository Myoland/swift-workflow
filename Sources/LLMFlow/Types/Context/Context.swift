import LazyKit
import Logging
import SynchronizationKit

public typealias AnySendable = Any & Sendable

public protocol AnyStorageValue: Sendable {}

public protocol ServiceLocator: AnyStorageValue {
    func resolve<T>(shared type: T.Type) -> T?
    func resolve<K, T>(for key: K.Type, as type: T.Type) -> T?
}

public typealias DataKeyPaths = [DataKeyPath]
public typealias DataKeyPath = String

public final class Context: Sendable {
    public typealias Key = DataKeyPath
    public typealias Value = AnySendable

    public typealias Store = [Key: Value]

    public let output: LazyLockedValue<NodeOutput> // May be rename to other name ?
    public let store: LazyLockedValue<Store>

    public let snapshots: LazyLockedValue<[Snapshot]>

    public init(output: NodeOutput = .none, store: Store = [:]) {
        self.output = .init(output)
        self.store = .init(store)
        self.snapshots = .init([])
    }
}

// MARK: Context + Store Access

extension Context {
    public subscript(key: Key?) -> Value? {
        get {
            store.withLock { store in
                store[safe: key]
            }
        }

        set {
            store.withLock { store in
                store[safe: key] = newValue
            }
        }
    }

    public subscript<T>(safe key: Key?, as type: T.Type = T.self) -> T? {
        get {
            store.withLock { store in
                store[safe: key] as? T
            }
        }
    }

    public subscript(path keys: Key...) -> Value? {
        get {
            self[path: keys]
        }

        set {
            self[path: keys] = newValue
        }
    }

    public subscript(path keys: [Key]?) -> Value? {
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
