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
    private let repository = FakeSymbolsRepository()
    private let symbols: [StockSymbol] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]

    /// A store with `symbols` already loaded.
    private func makeStore() async -> StockPriceStore {
        repository.result = .success(symbols)
        let store = StockPriceStore(repository: repository, feed: feed)
        await store.loadSymbols()
        return store
    }

    @Test func startsWithReferencePricesAndNoChange() async {
        let store = await makeStore()
        #expect(store.quote(for: symbols[0]) == StockQuote(price: 10, change: 0))
        #expect(store.connectionState == .disconnected)
    }

    @Test func priceUpdateRecordsNewPriceAndChange() async {
        let store = await makeStore()

        store.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12.5)]))
        #expect(store.quote(for: symbols[0]) == StockQuote(price: 12.5, change: 2.5))
        #expect(store.quote(for: symbols[0]).direction == .up)

        store.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 11)]))
        #expect(store.quote(for: symbols[0]) == StockQuote(price: 11, change: -1.5))
        #expect(store.quote(for: symbols[0]).direction == .down)
    }

    @Test func updatesForUnknownSymbolsAreIgnored() async {
        let store = await makeStore()
        let before = store.quotes

        store.apply(.priceUpdates([PriceUpdate(symbol: "ZZZ", price: 1)]))

        #expect(store.quotes == before)
    }

    @Test func sortsByPriceDescending() async {
        let store = await makeStore()
        store.sortOrder = .price
        #expect(store.sortedSymbols.map(\.ticker) == ["BBB", "CCC", "AAA"])
    }

    @Test func sortsByPriceChangeDescendingWithTickerTieBreak() async {
        let store = await makeStore()
        store.apply(.priceUpdates([
            PriceUpdate(symbol: "AAA", price: 11),   // +1
            PriceUpdate(symbol: "BBB", price: 29),   // -1
        ]))
        store.sortOrder = .priceChange
        // CCC is unchanged (0) and sits between the riser and the faller.
        #expect(store.sortedSymbols.map(\.ticker) == ["AAA", "CCC", "BBB"])
    }

    @Test(arguments: [ConnectionState.connecting, .connected])
    func toggleStopsARunningFeed(state: ConnectionState) async {
        let store = await makeStore()
        store.apply(.connectionChanged(state))

        store.toggleFeed()

        #expect(feed.stopCount == 1)
        #expect(feed.startCount == 0)
    }

    @Test func toggleStartsAStoppedFeed() async {
        let store = await makeStore()

        store.toggleFeed()

        #expect(feed.startCount == 1)
        #expect(feed.stopCount == 0)
    }

    @Test func appLifecycleSuspendsAndResumesTheFeed() async {
        let store = await makeStore()

        store.appDidEnterBackground()
        store.appDidBecomeActive()

        #expect(feed.suspendCount == 1)
        #expect(feed.resumeCount == 1)
    }

    @Test func observeFeedAppliesEventsInOrder() async {
        let store = await makeStore()
        feed.continuation.yield(.connectionChanged(.connected))
        feed.continuation.yield(.priceUpdates([PriceUpdate(symbol: "CCC", price: 25)]))
        feed.continuation.finish()

        await store.observeFeed()

        #expect(store.connectionState == .connected)
        #expect(store.quote(for: symbols[2]) == StockQuote(price: 25, change: 5))
    }

    @Test func loadingSymbolsTracksThemInTheFeed() async {
        _ = await makeStore()
        #expect(feed.trackedSymbols == symbols)
    }

    @Test func reloadKeepsQuotesOfRemainingSymbolsAndAddsNewOnes() async {
        let store = await makeStore()
        store.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 15)]))
        repository.result = .success([symbols[0], .fixture("DDD", price: 5)])

        await store.loadSymbols()

        #expect(store.symbols.map(\.ticker) == ["AAA", "DDD"])
        #expect(store.quote(for: symbols[0]) == StockQuote(price: 15, change: 5))
        #expect(store.quotes["BBB"] == nil)
        #expect(store.quotes["DDD"] == StockQuote(price: 5))
    }

    @Test func duplicateTickersKeepTheFirstOccurrence() async {
        let store = await makeStore()
        repository.result = .success([.fixture("AAA", price: 1), .fixture("AAA", price: 2)])

        await store.loadSymbols()

        #expect(store.symbols.count == 1)
        #expect(store.symbols.first?.referencePrice == 1)
    }

    @Test func failedLoadRaisesAlertAndKeepsCurrentSymbols() async {
        let store = await makeStore()
        repository.result = .failure(TestError())

        await store.loadSymbols()

        #expect(store.alert == .symbolsUnavailable)
        #expect(store.symbols == symbols)
        #expect(!store.isLoadingSymbols)
    }

    @Test func retryingFailedLoadClearsAlertAndReloads() async {
        let store = await makeStore()
        repository.result = .failure(TestError())
        await store.loadSymbols()
        repository.result = .success([symbols[1]])

        await store.retry(.symbolsUnavailable)

        #expect(store.alert == nil)
        #expect(store.symbols == [symbols[1]])
    }

    @Test func refreshReconnectsFeedAndReloadsSymbols() async {
        let store = await makeStore()
        repository.result = .success([symbols[2]])

        await store.refresh()

        #expect(feed.reconnectCount == 1)
        #expect(store.symbols == [symbols[2]])
    }

    @Test func connectionLostRaisesAlertAndRetryReconnects() async {
        let store = await makeStore()

        store.apply(.connectionLost)
        #expect(store.alert == .connectionLost)

        await store.retry(.connectionLost)
        #expect(store.alert == nil)
        #expect(feed.reconnectCount == 1)
    }

    @Test func connectionLostDoesNotReplaceAnUnseenAlert() async {
        let store = await makeStore()
        repository.result = .failure(TestError())
        await store.loadSymbols()

        store.apply(.connectionLost)

        #expect(store.alert == .symbolsUnavailable)
    }
}
