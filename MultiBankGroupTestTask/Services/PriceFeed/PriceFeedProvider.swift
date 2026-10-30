//
//  PriceFeedProvider.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 30/10/2026.
//

import Foundation

nonisolated enum PriceFeedEvent: Equatable, Sendable {
    case connectionChanged(ConnectionState)
    case priceUpdates([PriceUpdate])
    /// The live connection failed. Sent once per outage; the feed keeps retrying on its own.
    /// `reason` describes the underlying error, for debugging.
    case connectionLost(reason: String)
}

nonisolated
protocol StockSymbolPriceTracker {
    /// Generates updates for these symbols from now on, starting from the given prices.
    func track(_ symbolPrices: [StockSymbolPrice]) async
    /// Single-consumer stream that lives as long as the feed, across start/stop cycles.
    nonisolated var events: AsyncStream<PriceFeedEvent> { get }
}

/// A source of live prices that can be started and stopped. An actor, so feed work never runs on
/// the main thread; callers interact with it asynchronously.
protocol PriceFeedProvider: Actor, StockSymbolPriceTracker {
    /// User intent: keep the feed running, reconnecting as needed.
    func start()
    /// User intent: stop the feed.
    func stop()
    /// App went to the background: drop the connection but remember whether the feed was running.
    func suspend()
    /// App is active again: reconnect if the feed was running before `suspend()`.
    func resume()
    /// Reconnects immediately if the feed is running, skipping any backoff wait.
    func reconnect()
}
