//
//  AppState.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// The whole app state as a single value. Only `AppReducer` produces new states.
nonisolated struct AppState: Equatable, Sendable {
    enum SortOrder: CaseIterable, Hashable, Sendable {
        case price
        case priceChange
    }

    /// A problem worth interrupting the user for.
    enum Alert: Equatable, Sendable {
        case symbolsUnavailable
        case connectionLost
    }

    var symbols: [StockSymbol] = []
    var quotes: [String: StockQuote] = [:]
    var connectionState: ConnectionState = .disconnected
    var isLoadingSymbols = false
    var alert: Alert?
    var sortOrder: SortOrder = .price

    var isFeedRunning: Bool { connectionState.isActive }

    /// Symbols ordered by `sortOrder`, highest first; ties fall back to ticker order.
    var sortedSymbols: [StockSymbol] {
        symbols.sorted { lhs, rhs in
            let lhsQuote = quote(for: lhs)
            let rhsQuote = quote(for: rhs)
            let (lhsValue, rhsValue) = switch sortOrder {
            case .price: (lhsQuote.price, rhsQuote.price)
            case .priceChange: (lhsQuote.change, rhsQuote.change)
            }
            return lhsValue == rhsValue ? lhs.ticker < rhs.ticker : lhsValue > rhsValue
        }
    }

    func quote(for symbol: StockSymbol) -> StockQuote {
        quotes[symbol.ticker] ?? StockQuote(price: symbol.referencePrice)
    }
}

extension ConnectionState {
    /// The feed is running or trying to: anything but `disconnected`.
    nonisolated var isActive: Bool { self != .disconnected }
}
