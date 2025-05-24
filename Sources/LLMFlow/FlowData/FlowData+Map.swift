extension FlowData {
    public struct Map: Sendable {
        // Can not using `Single` as Dictionary Key for now.
        //
        // See [SE-0320: Allow coding of non String / Int keyed Dictionary into a KeyedContainer]
        // (https://github.com/swiftlang/swift-evolution/blob/main/proposals/0320-codingkeyrepresentable.md)
        // for more informations.
        public typealias Key = String
        public typealias Value = FlowData
        public typealias Element = (Key, Value)
        public typealias Elements = [Key: Value]

        let elemDecl: Value.TypeDecl
        let elememts: Elements

        public init(elements: Elements) {
            self.elememts = elements
            self.elemDecl = elements.values.decl
        }

        subscript(key: Key) -> Value? {
            get {
                elememts[key]
            }
        }
    }

    public var map: Map? {
        if case let .map(list) = self {
            return list
        }
        return nil
    }

}

extension FlowData.Map: Hashable {}
