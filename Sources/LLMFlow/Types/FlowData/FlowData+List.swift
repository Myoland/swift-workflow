public extension FlowData {
    struct List: Sendable {
        public typealias Element = FlowData

        let elemDecl: FlowData.TypeDecl
        let elements: [Element]

        public init(elements: [Element]) {
            self.elements = elements
            self.elemDecl = elements.decl
        }
    }

    var list: List? {
        if case .list(let list) = self {
            return list
        }
        return nil
    }
}

extension FlowData.List: Hashable {}
