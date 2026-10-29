//
//  StockSymbolsMarketModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// The live connection, shared by every screen: the WebSocket feed's state and the live quote of each
/// tracked symbol. Which symbols exist is the list's business; this model only prices what it's told to track.
///
/// Main-actor isolated because SwiftUI observes it. The feed it drives is an actor, so feed work runs
/// off the main thread and results come back here with `await`.
@MainActor
@Observable
final class StockSymbolsMarketModel {
    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var connectionState: ConnectionState = .disconnected

    /// Called once per outage with a description of the underlying error.
    @ObservationIgnored var onConnectionLost: (@MainActor (String) -> Void)?

    private let feed: any StockSymbolPriceTracker
    /// What the feed generates prices for.
    private var tracked: [StockSymbolPrice] = []

    init(feed: any StockSymbolPriceTracker) {
        self.feed = feed
    }

    var isFeedRunning: Bool { connectionState != .disconnected }

    func quote(for ticker: String) -> StockQuote? {
        quotes[ticker]
    }

    /// Prices exactly these symbols from now on. Symbols already tracked keep their live quote; new ones
    /// start from the given price; others are dropped. Duplicate tickers keep the first occurrence.
    func track(_ symbolPrices: [StockSymbolPrice]) async {
        var seen = Set<String>()
        tracked = symbolPrices.filter { seen.insert($0.symbol.ticker).inserted }
        quotes = Dictionary(uniqueKeysWithValues: tracked.map { symbolPrice in
            let ticker = symbolPrice.symbol.ticker
            return (ticker, quotes[ticker] ?? StockQuote(price: symbolPrice.price, updatedAt: symbolPrice.timestamp))
        })
        await track()
    }
    
    private func track() async {
        await feed.track(tracked)
    }

    /// Stops pricing one symbol, e.g. after the backend deleted it.
    func untrack(ticker: String) async {
        tracked.removeAll { $0.symbol.ticker == ticker }
        quotes.removeValue(forKey: ticker)
        // The feed keeps its own prices for symbols it already tracks.
        await track()
    }

    /// Takes a price from the backend when it's newer than the live quote; an older one is ignored.
    func applyIfNewer(_ symbolPrice: StockSymbolPrice) {
        let ticker = symbolPrice.symbol.ticker
        guard let quote = quotes[ticker], symbolPrice.timestamp > quote.updatedAt else { return }
        quotes[ticker] = quote.updated(to: symbolPrice.price, at: symbolPrice.timestamp)
    }

    /// Applies feed events until the feed's stream ends. Run once for the model's lifetime.
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
                quotes[update.symbol] = quote.updated(to: update.price, at: update.timestamp)
            }
        case .connectionLost(let reason):
            onConnectionLost?(reason)
        }
    }
}
