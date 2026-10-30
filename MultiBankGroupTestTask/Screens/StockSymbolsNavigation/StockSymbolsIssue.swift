//
//  StockSymbolsIssue.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// A problem worth interrupting the user for. View models and the price listener report these to the
/// navigation view model, which shows one alert at a time.
nonisolated enum StockSymbolsIssue: Equatable, Sendable {
    case symbolsUnavailable
    case symbolUnavailable(ticker: String)
    case connectionLost
}

/// Reports an issue together with a description of the underlying error (shown in Debug builds).
typealias StockSymbolsIssueHandler = @MainActor (StockSymbolsIssue, String) -> Void
