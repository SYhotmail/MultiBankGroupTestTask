//
//  AppAction.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// Everything that can happen to the app: user intents, lifecycle and effect results.
nonisolated enum AppAction: Equatable, Sendable {
    // User intents
    case toggleFeedTapped
    case loadSymbols
    case refreshRequested
    case sortOrderChanged(AppState.SortOrder)
    case alertDismissed
    case alertRetryTapped(AppState.Alert)

    // App lifecycle
    case appEnteredBackground
    case appBecameActive

    // Effect results
    case symbolsLoaded([StockSymbol])
    case symbolsLoadFailed
    case feed(PriceFeedEvent)
}

/// Side effects the reducer asks for. `AppStore` performs them; the reducer never does.
nonisolated enum AppEffect: Equatable, Sendable {
    case startFeed
    case stopFeed
    case suspendFeed
    case resumeFeed
    case reconnectFeed
    case trackSymbols([StockSymbol])
    case fetchSymbols
}
