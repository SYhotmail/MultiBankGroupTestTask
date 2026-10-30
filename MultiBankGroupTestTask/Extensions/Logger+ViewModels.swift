//
//  Logger+ViewModels.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import OSLog

extension Logger {
    /// What the screens' view models do: loads, refreshes, feed controls and reported issues.
    /// Filter in Console with `subsystem:<bundle id> category:ViewModels`.
    /// Tests pass `Logger.empty` instead, which discards everything.
    static let viewModels = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MultiBankGroupTestTask", category: "ViewModels")
}
