@testable import LLMFlow
import GPT

public final class DummySimpleLocater: ServiceLocator {
    public typealias Store = AnySendable

    let stores: [Store]

    public init(_ stores: Store...) {
        self.stores = stores
    }

    public func resolve<T>(shared _: T.Type) -> T? {
        (stores.first { $0 is T }) as? T
    }

    public func resolve<K, T>(for _: K.Type, as _: T.Type) -> T? {
        (stores.first { $0 is T }) as? T
    }
}

public struct DummyLLMProviderSolver: LLMProviderSolver, Sendable {
    let store: [String: LLMQualifiedModel]

    public init(_ store: [String: LLMQualifiedModel]) {
        self.store = store
    }

    public init(_ name: String, _ provider: LLMQualifiedModel) {
        store = [name: provider]
    }

    public func resolve(modelName: String) -> LLMQualifiedModel? {
        store[modelName]
    }
}
