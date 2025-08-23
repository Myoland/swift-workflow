//
//  Node+Type.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//


// MARK: Node + Type

public struct NodeType: RawRepresentable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension NodeType {
    static let START = NodeType(rawValue: "START")
    static let END = NodeType(rawValue: "END")
    static let TEMPLATE = NodeType(rawValue: "TEMPLATE")
    static let LLM = NodeType(rawValue: "LLM")
}

extension NodeType: Codable {}
extension NodeType: Hashable {}
