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

extension Logger {
    /// A disabled logger that performs no operations.
    static let disabled = Self(label: .Log.subsystem, factory: { _ in SwiftLogNoOpLogHandler() })

    /// The internal logger for the workflow system.
    ///
    /// This logger is active only in `DEBUG` builds. In `RELEASE` builds, it is replaced by a `disabled` logger
    /// to avoid logging overhead.
    #if DEBUG
        static let Internal = Self(label: .Log.subsystem)
    #else
        static let Internal = disabled
    #endif
}
