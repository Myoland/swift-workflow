import LazyKit
import Logging
import SynchronizationKit

public typealias AnySendable = Any & Sendable

public protocol AnyStorageValue: Sendable {}

/// A protocol for a dependency injection container that provides services to workflow nodes.
///
/// The `ServiceLocator` is used by nodes (e.g., `LLMNode`) to resolve dependencies like API clients
/// for external services.
public protocol ServiceLocator: AnyStorageValue {
    /// Resolves a service of a given type.
    func resolve<T>(shared type: T.Type) -> T?
    /// Resolves a service for a given key and type.
    func resolve<T>(for key: (some Any).Type, as type: T.Type) -> T?
}

/// A key path for accessing nested values within a ``Context/Store``.
public typealias ContextStoreKeyPath = [ContextStoreKey]
/// A key for storing and retrieving values in a ``Context/Store``.
public typealias ContextStoreKey = String

/// A thread-safe container for managing the state and data of a running ``Workflow``.
///
/// The `Context` serves as the central repository for all data within a workflow. It holds:
/// - A `store` for arbitrary key-value data that can be accessed and modified by nodes.
/// - A `payload` that holds the most recent output of a node.
/// - A series of `snapshots` that capture the state of the context at different points in time.
///
/// `Context` is a reference type (`final class`) to ensure that all nodes in a workflow run share the same
/// state. Access to its internal storage is synchronized to prevent data races.
public final class Context: Sendable {
    /// A type alias for a key in the context store.
    public typealias Key = ContextStoreKey
    /// A type alias for a value in the context store.
    public typealias Value = AnySendable

    /// The underlying dictionary that holds the workflow's state.
    public typealias Store = [Key: Value]

    /// The most recent output produced by a node. This is used to pass data between nodes implicitly.
    public let payload: LazyLockedValue<NodeOutput?>
    /// The main key-value store for the workflow's state.
    public let store: LazyLockedValue<Store>

    /// A log of historical states of the context, used for debugging and introspection.
    public let snapshots: LazyLockedValue<[Snapshot]>

    /// Initializes a new `Context`.
    /// - Parameters:
    ///   - payload: The initial node output payload.
    ///   - store: The initial key-value store.
    public init(payload: NodeOutput? = nil, store: Store = [:]) {
        self.payload = .init(payload)
        self.store = .init(store)
        self.snapshots = .init([])
    }
}

// MARK: Context + Store Access

public extension Context {
    subscript(key: Key?) -> Value? {
        get {
            store.withLock { store in
                store[path: key]
            }
        }

        set {
            store.withLock { store in
                store[path: key] = newValue
            }
        }
    }

    subscript<T>(safe key: Key?, as _: T.Type = T.self) -> T? {
        store.withLock { store in
            store[path: key] as? T
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

public extension Context {
    func filter(keys: [Key]?) -> [Key: Value] {
        guard let keys else {
            return store.withLock { $0 }
        }

        return store.withLock { store in
            store.filter { keys.contains($0.key) }
        }
    }

    func filter<T>(keys: [Key]?, as _: T.Type) -> [Key: T] {
        guard let keys else {
            return store.withLock { $0.compactMapValues { $0 as? T } }
        }

        return store.withLock { store in
            store.filter { keys.contains($0.key) }.compactMapValues { $0 as? T }
        }
    }
}
