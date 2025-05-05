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
    public typealias Value = FlowData
    public typealias Variable = (key: Key, value: Value)

    public typealias Store = [Key: Value]

    var states: [State] = []
    var store: Store = [:]
    var locator: StoreLocator?

    public init(locater: StoreLocator? = nil) {
        self.locator = locater
    }

    public mutating func update(_ variable: Variable) {
        store[variable.key] = variable.value
    }

    public mutating func update(key: Key, value: Value) {
        store[key] = value
    }
}

public enum FlowData: Sendable {
    case single(Single)
    case list(List)
    case map(Map)
}

extension FlowData: Hashable {}
