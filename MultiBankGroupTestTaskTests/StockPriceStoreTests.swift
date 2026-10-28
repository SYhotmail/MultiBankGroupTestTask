//
//  StockPriceStoreTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

@MainActor
struct StockPriceStoreTests {
    private let feed = FakePriceFeed()
    private let symbols: [StockSymbol] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]

    private func makeStore() -> StockPriceStore {
        StockPriceStore(symbols: symbols, feed: feed)
    }

    @Test func startsWithReferencePricesAndNoChange() {
        let store = makeStore()
        #expect(store.quote(for: symbols[0]) == StockQuote(price: 10, change: 0))
        #expect(store.connectionState == .disconnected)
    }

    @Test func priceUpdateRecordsNewPriceAndChange() {
        let store = makeStore()

        store.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12.5)]))
        #expect(store.quote(for: symbols[0]) == StockQuote(price: 12.5, change: 2.5))
        #expect(store.quote(for: symbols[0]).direction == .up)

        store.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 11)]))
        #expect(store.quote(for: symbols[0]) == StockQuote(price: 11, change: -1.5))
        #expect(store.quote(for: symbols[0]).direction == .down)
    }

    @Test func updatesForUnknownSymbolsAreIgnored() {
        let store = makeStore()
        let before = store.quotes

        store.apply(.priceUpdates([PriceUpdate(symbol: "ZZZ", price: 1)]))

        #expect(store.quotes == before)
    }

    @Test func sortsByPriceDescending() {
        let store = makeStore()
        store.sortOrder = .price
        #expect(store.sortedSymbols.map(\.ticker) == ["BBB", "CCC", "AAA"])
    }

    @Test func sortsByPriceChangeDescendingWithTickerTieBreak() {
        let store = makeStore()
        store.apply(.priceUpdates([
            PriceUpdate(symbol: "AAA", price: 11),   // +1
            PriceUpdate(symbol: "BBB", price: 29),   // -1
        ]))
        store.sortOrder = .priceChange
        // CCC is unchanged (0) and sits between the riser and the faller.
        #expect(store.sortedSymbols.map(\.ticker) == ["AAA", "CCC", "BBB"])
    }

    @Test(arguments: [ConnectionState.connecting, .connected])
    func toggleStopsARunningFeed(state: ConnectionState) {
        let store = makeStore()
        store.apply(.connectionChanged(state))

        store.toggleFeed()

        #expect(feed.stopCount == 1)
        #expect(feed.startCount == 0)
    }

    @Test func toggleStartsAStoppedFeed() {
        let store = makeStore()

        store.toggleFeed()

        #expect(feed.startCount == 1)
        #expect(feed.stopCount == 0)
    }

    @Test func appLifecycleSuspendsAndResumesTheFeed() {
        let store = makeStore()

        store.appDidEnterBackground()
        store.appDidBecomeActive()

        #expect(feed.suspendCount == 1)
        #expect(feed.resumeCount == 1)
    }

    @Test func observeFeedAppliesEventsInOrder() async {
        let store = makeStore()
        feed.continuation.yield(.connectionChanged(.connected))
        feed.continuation.yield(.priceUpdates([PriceUpdate(symbol: "CCC", price: 25)]))
        feed.continuation.finish()

        await store.observeFeed()

        #expect(store.connectionState == .connected)
        #expect(store.quote(for: symbols[2]) == StockQuote(price: 25, change: 5))
    }
}
