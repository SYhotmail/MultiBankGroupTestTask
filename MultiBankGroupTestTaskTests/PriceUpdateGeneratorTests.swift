//
//  PriceUpdateGeneratorTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

struct PriceUpdateGeneratorTests {
    private let symbols = StockSymbol.catalog

    private func makeGenerator(seed: UInt64) -> PriceUpdateGenerator {
        PriceUpdateGenerator(symbols: symbols, maxChangeRatio: 0.02, maxUpdatesPerBatch: 5, rng: SeededRandomNumberGenerator(seed: seed))
    }

    @Test func sameSeedProducesSameSequence() {
        var first = makeGenerator(seed: 42)
        var second = makeGenerator(seed: 42)
        for _ in 0..<20 {
            #expect(first.next() == second.next())
        }
    }

    @Test(arguments: [1, 7, 99] as [UInt64])
    func batchesUpdateDistinctKnownSymbols(seed: UInt64) {
        var generator = makeGenerator(seed: seed)
        let tickers = Set(symbols.map(\.ticker))
        for _ in 0..<50 {
            let batch = generator.next()
            #expect((1...5).contains(batch.count))
            #expect(Set(batch.map(\.symbol)).count == batch.count)
            #expect(batch.allSatisfy { tickers.contains($0.symbol) })
        }
    }

    @Test func pricesStayPositiveAndMoveWithinTheConfiguredRatio() {
        var generator = makeGenerator(seed: 3)
        var last = Dictionary(uniqueKeysWithValues: symbols.map { ($0.ticker, $0.referencePrice) })
        for _ in 0..<200 {
            for update in generator.next() {
                let previous = last[update.symbol]!
                // 2% bound plus one cent of rounding slack.
                let bound = previous * Decimal(0.02) + Decimal(0.01)
                #expect(update.price > 0)
                #expect(abs(update.price - previous) <= bound)
                #expect(update.price == update.price.rounded(scale: 2))
                last[update.symbol] = update.price
            }
        }
    }

    @Test func trackKeepsCurrentPricesAndAddsNewSymbolsAtReference() {
        var generator = PriceUpdateGenerator(symbols: [.fixture("AAA", price: 10)], maxUpdatesPerBatch: 1, rng: SeededRandomNumberGenerator(seed: 5))
        let moved = generator.next()[0].price

        generator.track([.fixture("AAA", price: 10), .fixture("BBB", price: 50)])

        // The first update after tracking moves each symbol at most 2% (plus a cent of rounding)
        // from where it stood: AAA from its moved price, BBB from its reference price.
        for update in generator.next() {
            let base: Decimal = update.symbol == "AAA" ? moved : 50
            #expect(abs(update.price - base) <= base * Decimal(0.02) + Decimal(0.01))
        }
        #expect(Set((0..<20).flatMap { _ in generator.next().map(\.symbol) }) == ["AAA", "BBB"])
    }

    @Test func emptySymbolListProducesNoUpdates() {
        var generator = PriceUpdateGenerator(symbols: [], rng: SeededRandomNumberGenerator(seed: 1))
        #expect(generator.next().isEmpty)
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
