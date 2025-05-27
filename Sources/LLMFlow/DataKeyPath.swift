//
//  DataKeyPath.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/27.
//


public typealias DataKeyPaths = [DataKeyPath]

public struct DataKeyPath {
    public var rawValue: String
    
    package init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension DataKeyPath: CodingKeyRepresentable {}

extension DataKeyPath: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension DataKeyPath: CustomStringConvertible {
    public var description: String { self.rawValue }
}

extension DataKeyPath: Encodable {
    public func encode(to encoder: any Encoder) throws {
        try self.rawValue.encode(to: encoder)
    }
}

extension DataKeyPath: Equatable {
    public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension DataKeyPath: ExpressibleByStringLiteral {
    public init(stringLiteral rawValue: String) {
        self.init(rawValue)
    }
}

extension DataKeyPath: Decodable {
    public init(from decoder: any Decoder) throws {
        self.rawValue = try String(from: decoder)
    }
}

extension DataKeyPath: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.rawValue.hash(into: &hasher)
    }
}

extension DataKeyPath: RawRepresentable {
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension DataKeyPath: Sendable {}
