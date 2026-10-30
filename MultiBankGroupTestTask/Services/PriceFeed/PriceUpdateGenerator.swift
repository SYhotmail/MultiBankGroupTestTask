//
//  PriceUpdateGenerator.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

/// Produces random-walk price updates for a random subset of symbols on each call.
nonisolated
struct PriceUpdateGenerator: Sendable {
    private var tickers: [String] = []
    private var prices: [String: Decimal] = [:]
    private let maxChangeRatio: Double
    private let maxUpdatesPerBatch: Int
    private var rng: any RandomNumberGenerator & Sendable

    init(
        symbolPrices: [StockSymbolPrice],
        maxChangeRatio: Double = 0.02,
        maxUpdatesPerBatch: Int = 10,
        rng: any RandomNumberGenerator & Sendable = SystemRandomNumberGenerator()
    ) {
        self.maxChangeRatio = maxChangeRatio
        self.maxUpdatesPerBatch = max(1, maxUpdatesPerBatch)
        self.rng = rng
        track(symbolPrices)
    }

    /// Switches to a new symbol list. Symbols already tracked keep their current price; new ones
    /// start at the given price.
    mutating func track(_ symbolPrices: [StockSymbolPrice]) {
        var newPrices: [String: Decimal] = [:]
        for symbolPrice in symbolPrices {
            let ticker = symbolPrice.symbol.ticker
            newPrices[ticker] = prices[ticker] ?? symbolPrice.price
        }
        tickers = symbolPrices.map(\.symbol.ticker)
        prices = newPrices
    }

    /// Next batch of updates stamped with `timestamp`; empty when no symbols are tracked.
    mutating func next(at timestamp: Date) -> [PriceUpdate] {
        guard !tickers.isEmpty else { return [] }
        let count = Int.random(in: 1...min(maxUpdatesPerBatch, tickers.count), using: &rng)
        return tickers.shuffled(using: &rng).prefix(count).map { ticker in
            let price = nextPrice(after: prices[ticker, default: 0])
            prices[ticker] = price
            return PriceUpdate(symbol: ticker, price: price, timestamp: timestamp)
        }
    }

    private mutating func nextPrice(after price: Decimal) -> Decimal {
        let ratio = Double.random(in: -maxChangeRatio...maxChangeRatio, using: &rng)
        var raw = Decimal(max(0.01, NSDecimalNumber(decimal: price).doubleValue * (1 + ratio)))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .plain)
        return rounded
    }
}
