//
//  Context+Store.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-18.
//

/// A type-safe path for accessing nested data within a ``Context/Store``.
///
/// `ContextStorePath` allows you to specify a dot-separated path to a value within a nested structure
/// of dictionaries and arrays. It supports both string keys for dictionaries and integer indices for arrays.
///
/// ## Example
/// ```swift
/// let path = ContextStorePath("workflow.inputs.user_query")
/// let value = context[path: path]
/// ```
public struct ContextStorePath: Hashable, Sendable {
    /// A single component of a `ContextStorePath`, which can be either a string or an integer.
    public struct Key: Hashable, Sendable {
        let strValue: String
        let intValue: Int?

        /// Initializes a key from a string. If the string can be parsed as an integer, it will be.
        public init(strValue: String) {
            if let intValue = Int(strValue) {
                self.init(strValue: strValue, intValue: intValue)
            } else {
                self.init(strValue: strValue, intValue: nil)
            }
        }

        /// Initializes a key from an integer.
        public init(intValue: Int) {
            self.init(strValue: "\(intValue)", intValue: intValue)
        }

        init(strValue: String, intValue: Int?) {
            self.strValue = strValue
            self.intValue = intValue
        }
    }

    let keys: [Key]

    /// Initializes a path with an array of keys.
    public init(keys: [Key]) {
        self.keys = keys
    }
}

extension ContextStorePath: CustomStringConvertible {
    public var description: String {
        keys.map(\.strValue).joined(separator: ".")
    }
}

extension ContextStorePath: LosslessStringConvertible {
    public init(_ description: String) {
        let keys = description.split(separator: ".").map { ContextStorePath.Key(strValue: String($0)) }
        self.init(keys: keys)
    }
}

extension ContextStorePath: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(raw)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension ContextStorePath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension ContextStorePath: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(keys: [.init(intValue: value)])
    }
}

extension ContextStorePath.Key: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(strValue: value)
    }
}

extension ContextStorePath.Key: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(intValue: value)
    }
}

extension ContextStorePath: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: ContextStorePath.Key...) {
        self.init(keys: elements)
    }
}

// MARK: Lookup

public extension ContextStorePath {
    /// Thrown when a path indexes past the end of a list, or before its start (a negative index).
    ///
    /// ``Condition/evaluate(_:)`` throws it directly; ``ModelDecl/render(_:)`` wraps it in a
    /// `DecodingError.dataCorrupted` whose coding path is the request field holding the reference.
    struct IndexOutOfRangeError: Error, Hashable, Sendable, CustomStringConvertible {
        /// The whole path that was looked up.
        public let path: ContextStorePath
        /// The index that is out of range.
        public let index: Int
        /// The number of elements in the list.
        public let count: Int

        public init(path: ContextStorePath, index: Int, count: Int) {
            self.path = path
            self.index = index
            self.count = count
        }

        public var description: String {
            "`\(path)` reads index \(index) of a list with \(count) element(s)."
        }
    }
}

extension ContextStorePath {
    /// Looks the path up in `root`: an integer key indexes a list, any other key a map.
    ///
    /// - Returns: The value, or `nil` when the path is empty, a key is missing, or a value has another shape.
    /// - Throws: ``IndexOutOfRangeError`` when an integer key is outside a list's bounds.
    func lookup(in root: AnySendable) throws -> AnySendable? {
        guard !keys.isEmpty else { return nil }

        var current = root
        for key in keys {
            if let map = current as? [String: AnySendable] {
                guard key.intValue == nil, let next = map[key.strValue] else { return nil }
                current = next
            } else if let list = current as? [AnySendable] {
                guard let index = key.intValue else { return nil }
                guard list.indices.contains(index) else {
                    throw IndexOutOfRangeError(path: self, index: index, count: list.count)
                }
                current = list[index]
            } else {
                return nil
            }
        }
        return current
    }
}

// MARK: Collection

extension Collection<AnySendable> where Index == Int {
    subscript(key position: ContextStorePath.Key?) -> Element? {
        guard let idx = position?.intValue, indices.contains(idx) else {
            return nil
        }
        return self[idx]
    }

    subscript(path path: ContextStorePath?) -> Element? {
        guard let path else { return nil }
        return (try? path.lookup(in: Array(self))) ?? nil
    }
}

extension MutableCollection where Element == AnySendable, Index == Int {
    subscript(key position: ContextStorePath.Key?) -> Element? {
        get {
            guard let idx = position?.intValue, indices.contains(idx) else {
                return nil
            }
            return self[idx]
        }
        set {
            guard let idx = position?.intValue else {
                return
            }
            return self[idx] = newValue
        }
    }

    subscript(keys keys: [ContextStorePath.Key]?) -> Element? {
        get {
            guard let keys else { return nil }
            return (try? ContextStorePath(keys: keys).lookup(in: Array(self))) ?? nil
        }

        set {
            guard let keys else { return }

            let (key, rest) = keys.separateFirst()

            guard let rest, !rest.isEmpty else {
                self[key: key] = newValue
                return
            }

            if rest.first?.intValue == nil {
                var dict = self[key: key] as? [String: Element] ?? [:]
                dict[keys: rest] = newValue
                self[key: key] = dict
            } else {
                var list = self[key: key] as? [Element] ?? []
                list[keys: rest] = newValue
                self[key: key] = list
            }
        }
    }

    subscript(path path: ContextStorePath?) -> Element? {
        get {
            self[keys: path?.keys]
        }

        set {
            self[keys: path?.keys] = newValue
        }
    }
}

// MARK: Dictionary

extension [String: AnySendable] {
    // Designated Accesser
    subscript(key key: ContextStorePath.Key?) -> Value? {
        get {
            guard key?.intValue == nil, let key = key?.strValue else { return nil }
            return self[safe: key]
        }

        set {
            guard key?.intValue == nil, let key = key?.strValue else { return }
            self[safe: key] = newValue
        }
    }

    subscript(keys keys: [ContextStorePath.Key]?) -> Value? {
        get {
            guard let keys else { return nil }
            return (try? ContextStorePath(keys: keys).lookup(in: self)) ?? nil
        }

        set {
            guard let keys else { return }

            let (key, rest) = keys.separateFirst()

            guard let rest, !rest.isEmpty else {
                self[key: key] = newValue
                return
            }

            if rest.first?.intValue == nil {
                var dict = self[key: key] as? [String: Value] ?? [:]
                dict[keys: rest] = newValue
                self[key: key] = dict
            } else {
                var list = self[key: key] as? [Value] ?? []
                list[keys: rest] = newValue
                self[key: key] = list
            }
        }
    }
}

extension [String: AnySendable] {
    subscript(path path: ContextStorePath?) -> Value? {
        get {
            self[keys: path?.keys]
        }

        set {
            self[keys: path?.keys] = newValue
        }
    }

    subscript(path key: Key?) -> Value? {
        get {
            guard let key else { return nil }
            return self[path: ContextStorePath(key)]
        }

        set {
            guard let key else { return }
            self[path: ContextStorePath(key)] = newValue
        }
    }

    subscript(path keys: Key...) -> Value? {
        get {
            self[keys: keys.map { ContextStorePath.Key(strValue: $0) }]
        }

        set {
            self[keys: keys.map { ContextStorePath.Key(strValue: $0) }] = newValue
        }
    }

    subscript(path keys: [Key]?) -> Value? {
        get {
            self[keys: keys?.map { ContextStorePath.Key(strValue: $0, intValue: nil) }]
        }

        set {
            self[keys: keys?.map { ContextStorePath.Key(strValue: $0, intValue: nil) }] = newValue
        }
    }
}

extension Dictionary {
    private subscript(safe key: Key?) -> Value? {
        get {
            guard let key else { return nil }
            return self[key]
        }

        set {
            guard let key else { return }
            self[key] = newValue
        }
    }
}

private extension Collection {
    func separateFirst() -> (Element?, [Element]?) {
        (first, Array(dropFirst()))
    }
}
