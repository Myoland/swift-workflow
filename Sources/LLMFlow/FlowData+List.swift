extension FlowData {
    public struct List: Sendable {
        public typealias Element = FlowData

        let elemDecl: FlowData.TypeDecl
        let elements: [Element]

        public init(elements: [Element]) {
            self.elements = elements
            self.elemDecl = elements.decl
        }
    }

    public var list: List? {
        if case let .list(list) = self {
            return list
        }
        return nil
    }

}

extension FlowData.List: Hashable {
}
