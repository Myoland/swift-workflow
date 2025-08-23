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
    internal static let subsystem = "me.afuture.workflow"
}

extension Logger {
    internal static let disabled = Self(label: .Log.subsystem, factory: { _ in SwiftLogNoOpLogHandler() })

#if DEBUG
    static let Internal = Self(label: .Log.subsystem)
#else
    static let Internal = disabled
#endif

}
