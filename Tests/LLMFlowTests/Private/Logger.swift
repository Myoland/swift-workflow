//
//  Logger.swift
//  swift-workflow
//
//  Created by AFuture on 2025/8/4.
//

import Logging
@testable import LLMFlow

extension Logger {
    static let testing = Self(label: .Log.subsystem + ".tests")
}
