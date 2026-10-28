//
//  PriceUpdateGenerator.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

/// Produces random-walk price updates for a random subset of symbols on each call.
nonisolated struct PriceUpdateGenerator {
    private let tickers: [String]
    private var prices: [String: Decimal]
    private let maxChangeRatio: Double
    private let maxUpdatesPerBatch: Int
    private var rng: any RandomNumberGenerator

    init(
        symbols: [StockSymbol],
        maxChangeRatio: Double = 0.02,
        maxUpdatesPerBatch: Int = 5,
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        precondition(!symbols.isEmpty, "Generator needs at least one symbol")
        tickers = symbols.map(\.ticker)
        prices = Dictionary(uniqueKeysWithValues: symbols.map { ($0.ticker, $0.referencePrice) })
        self.maxChangeRatio = maxChangeRatio
        self.maxUpdatesPerBatch = max(1, min(maxUpdatesPerBatch, symbols.count))
        self.rng = rng
    }

    mutating func next() -> [PriceUpdate] {
        let count = Int.random(in: 1...maxUpdatesPerBatch, using: &rng)
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
