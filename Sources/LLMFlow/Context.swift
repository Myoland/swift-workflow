import LazyKit
import OSLog

public typealias AnySendable = Any & Sendable


extension Context {
    public struct Snapshot: Sendable {
        enum Change: Sendable {
            case insert(DataKeyPaths, Context.Value)
            // TODO: [2025/06/25 <Huanan>] Add update, delete
        }

        let createdAt: Date

        let modifiedBy: Node.ID
        let result: Context.Store

        let changes: [Change]
    }
}


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

    let output: LazyLock<NodeOutput>
    let store: LazyLock<Store>

    let snapshots: LazyLock<[Snapshot]>

    public init(output: NodeOutput = .none, store: Store = [:]) {
        self.output = .init(output)
        self.store = .init(store)
        self.snapshots = .init([])
    }
}

extension Context {
    subscript(key: Key?) -> Value? {
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


// [2025/06/02 <Huanan>] TODO: Support Collection. Such as `inputs.users.0.name`
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

            let (key, rest) = keys.separateFirst()

            guard let rest, !rest.isEmpty else {
                self[safe: key] = newValue
                return
            }

            var value =  self[safe: key] as? Dictionary<Key, Value> ?? [:]

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

public final class Executor: Sendable {
    public let locator: ServiceLocator?
    private let lockedContext: LazyLock<Context>
    public let logger: Logger

    public let anyDecoder = AnyDecoder()
    public let anyEncoder = AnyEncoder()

    public init(locator: ServiceLocator? = nil, context: Context = Context(), logger: Logger = .init()) {
        self.locator = locator
        self.lockedContext = .init(context)
        self.logger = logger
    }
}

extension Executor {
    var context: Context {
        get {
            self.lockedContext.withLock { $0 }
        }
    }
}
