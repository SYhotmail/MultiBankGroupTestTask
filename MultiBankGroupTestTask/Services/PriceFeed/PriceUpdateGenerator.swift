//
//  PriceUpdateGenerator.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

/// Produces random-walk price updates for a random subset of symbols on each call.
struct PriceUpdateGenerator: Sendable {
    private var tickers: [String] = []
    private var prices: [String: Decimal] = [:]
    private let maxChangeRatio: Double
    private let maxUpdatesPerBatch: Int
    private var rng: any RandomNumberGenerator & Sendable

    init(
        symbols: [StockSymbol],
        maxChangeRatio: Double = 0.02,
        maxUpdatesPerBatch: Int = 5,
        rng: any RandomNumberGenerator & Sendable = SystemRandomNumberGenerator()
    ) {
        self.maxChangeRatio = maxChangeRatio
        self.maxUpdatesPerBatch = max(1, maxUpdatesPerBatch)
        self.rng = rng
        track(symbols)
    }

    /// Switches to a new symbol list. Symbols already tracked keep their current price; new ones
    /// start at their reference price. Duplicate tickers keep the first occurrence.
    mutating func track(_ symbols: [StockSymbol]) {
        var newPrices: [String: Decimal] = [:]
        tickers = symbols.compactMap { symbol in
            guard newPrices[symbol.ticker] == nil else { return nil }
            newPrices[symbol.ticker] = prices[symbol.ticker] ?? symbol.referencePrice
            return symbol.ticker
        }
        prices = newPrices
    }

    /// Next batch of updates; empty when no symbols are tracked.
    mutating func next() -> [PriceUpdate] {
        guard !tickers.isEmpty else { return [] }
        let count = Int.random(in: 1...min(maxUpdatesPerBatch, tickers.count), using: &rng)
        return tickers.shuffled(using: &rng).prefix(count).map { ticker in
            let price = nextPrice(after: prices[ticker, default: 0])
            prices[ticker] = price
            return PriceUpdate(symbol: ticker, price: price)
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
