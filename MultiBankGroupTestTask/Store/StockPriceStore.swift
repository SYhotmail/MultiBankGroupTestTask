//
//  StockPriceStore.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Observation

/// Single source of truth for prices and feed state, shared by every screen.
@Observable
final class StockPriceStore {
    enum SortOrder: CaseIterable, Hashable {
        case price
        case priceChange
    }

    let symbols: [StockSymbol]
    private(set) var quotes: [String: StockQuote]
    private(set) var connectionState: ConnectionState = .disconnected
    var sortOrder: SortOrder = .price

    @ObservationIgnored private let feed: any PriceFeed

    init(symbols: [StockSymbol], feed: any PriceFeed) {
        self.symbols = symbols
        self.feed = feed
        quotes = Dictionary(uniqueKeysWithValues: symbols.map { ($0.ticker, StockQuote(price: $0.referencePrice)) })
    }

    var isFeedRunning: Bool { connectionState != .disconnected }

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

    func toggleFeed() {
        if isFeedRunning {
            feed.stop()
        } else {
            feed.start()
        }
    }

    /// Applies feed events until the feed's stream ends. Run once for the store's lifetime.
    func observeFeed() async {
        for await event in feed.events {
            apply(event)
        }
    }

    func apply(_ event: PriceFeedEvent) {
        switch event {
        case .connectionChanged(let state):
            connectionState = state
        case .priceUpdates(let updates):
            for update in updates {
                // Ignore symbols we do not track.
                guard let quote = quotes[update.symbol] else { continue }
                quotes[update.symbol] = quote.updated(to: update.price)
            }
        }
    }
}
