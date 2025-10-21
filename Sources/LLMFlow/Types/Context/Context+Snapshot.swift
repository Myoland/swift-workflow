//
//  Context+Snapshot.swift
//  swift-workflow
//
//  Created by Huanan on 2025/7/25.
//

import Foundation

public extension Context {
    struct Snapshot: Sendable {
        public enum Change: Sendable {
            case insert(ContextStoreKeyPath, Context.Value)
            // TODO: [2025/06/25 <Huanan>] Add update, delete
        }

        public let createdAt: Date

        public let modifiedBy: Node.ID
        public let result: Context.Store

        public let changes: [Change]
    }
}
