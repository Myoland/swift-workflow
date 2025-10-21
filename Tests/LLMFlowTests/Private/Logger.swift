//
//  Logger.swift
//  swift-workflow
//
//  Created by AFuture on 2025/8/4.
//

@testable import LLMFlow
import Logging

public extension Logger {
    static let testing = Self(label: .Log.subsystem + ".tests")
}
