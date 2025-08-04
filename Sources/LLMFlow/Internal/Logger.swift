//
//  Logger.swift
//  swift-workflow
//
//  Created by Huanan on 2025/7/25.
//

import Logging

extension String {
    enum Log {}
}

extension String.Log {
    static let subsystem = "me.afuture.workflow"
}

extension String.Log {
    enum Category {}
}

extension String.Log.Category {
    static let workflow = "Workflow"
    static let executor = "Executor"
}
