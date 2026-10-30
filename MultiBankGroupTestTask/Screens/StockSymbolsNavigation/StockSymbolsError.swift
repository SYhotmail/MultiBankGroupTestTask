//
//  StockSymbolsError.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// A problem worth interrupting the user for. View models and the price listener report these to the
/// navigation view model, which shows one alert at a time.
nonisolated enum StockSymbolsError: LocalizedError, Equatable {
    case symbolsUnavailable
    case symbolUnavailable(ticker: String)
    case connectionLost

    /// The alert's title.
    var errorDescription: String? {
        switch self {
        case .symbolsUnavailable: String(localized: "Couldn't Load Symbols")
        case .symbolUnavailable(let ticker): String(localized: "Couldn't Refresh \(ticker)")
        case .connectionLost: String(localized: "Connection Problem")
        }
    }

    /// The alert's message.
    var recoverySuggestion: String? {
        switch self {
        case .symbolsUnavailable, .symbolUnavailable: String(localized: "Check your connection and try again.")
        case .connectionLost: String(localized: "Live prices are unavailable. The app will keep trying to reconnect.")
        }
    }
}

/// Reports an error together with a description of the underlying error (shown in Debug builds).
typealias StockSymbolsErrorHandler = @MainActor (StockSymbolsError, String) -> Void
