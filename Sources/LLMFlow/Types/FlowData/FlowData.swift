
public enum FlowData: Sendable {
    case single(Single)
    case list(List)
    case map(Map)
}

extension FlowData: Hashable {}
