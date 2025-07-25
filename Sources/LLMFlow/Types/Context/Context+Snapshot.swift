//
//  Context+Snapshot.swift
//  swift-workflow
//
//  Created by Huanan on 2025/7/25.
//

import Foundation



extension Context {
    public struct Snapshot: Sendable {
        public enum Change: Sendable {
            case insert(DataKeyPaths, Context.Value)
            // TODO: [2025/06/25 <Huanan>] Add update, delete
        }

        public let createdAt: Date

        public let modifiedBy: Node.ID
        public let result: Context.Store

        public let changes: [Change]
    }
}
