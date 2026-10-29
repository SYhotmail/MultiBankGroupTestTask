//
//  AppReducer.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// The only place state changes. Pure: given the same state and action it always produces the
/// same new state and effects, and it performs no I/O itself.
nonisolated enum AppReducer {
    static func reduce(_ state: inout AppState, _ action: AppAction) -> [AppEffect] {
        switch action {
        case .toggleFeedTapped:
            return [state.isFeedRunning ? .stopFeed : .startFeed]

        case .loadSymbols:
            state.isLoadingSymbols = true
            return [.fetchSymbols]

        case .refreshRequested:
            state.isLoadingSymbols = true
            return [.reconnectFeed, .fetchSymbols]

        case .sortOrderChanged(let order):
            state.sortOrder = order
            return []

        case .alertDismissed:
            state.alert = nil
            return []

        case .alertRetryTapped(let alert):
            state.alert = nil
            switch alert {
            case .symbolsUnavailable:
                state.isLoadingSymbols = true
                return [.fetchSymbols]
            case .connectionLost:
                return [.reconnectFeed]
            }

        case .appEnteredBackground:
            return [.suspendFeed]

        case .appBecameActive:
            return [.resumeFeed]

        case .symbolsLoaded(let fetched):
            state.isLoadingSymbols = false
            // Remote data may repeat a ticker; keep the first so tickers stay unique identifiers.
            var seen = Set<String>()
            let symbols = fetched.filter { seen.insert($0.ticker).inserted }
            // Symbols that remain keep their quote; new ones start at their reference price.
            state.quotes = Dictionary(uniqueKeysWithValues: symbols.map { ($0.ticker, state.quote(for: $0)) })
            state.symbols = symbols
            return [.trackSymbols(symbols)]

        case .symbolsLoadFailed:
            state.isLoadingSymbols = false
            state.alert = .symbolsUnavailable
            return []

        case .feed(.connectionChanged(let connectionState)):
            state.connectionState = connectionState
            return []

        case .feed(.priceUpdates(let updates)):
            for update in updates {
                // Ignore symbols we do not track.
                guard let quote = state.quotes[update.symbol] else { continue }
                state.quotes[update.symbol] = quote.updated(to: update.price)
            }
            return []

        case .feed(.connectionLost):
            // Don't replace an alert the user hasn't seen yet.
            state.alert = state.alert ?? .connectionLost
            return []
        }
    }
}
