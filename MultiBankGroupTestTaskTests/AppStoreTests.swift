//
//  AppStoreTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// The reducer's logic is covered by `AppReducerTests`; these check that the store performs the
/// effects it returns against real collaborators (here, fakes) and feeds results back as actions.
@MainActor
struct AppStoreTests {
    private let feed = FakePriceFeed()
    private let repository = FakeSymbolsRepository()
    private let symbols: [StockSymbol] = [.fixture("AAA", price: 10), .fixture("BBB", price: 30)]

    private func makeStore() -> AppStore {
        AppStore(repository: repository, feed: feed)
    }

    @Test func feedEffectsReachTheFeed() async {
        let store = makeStore()

        await store.send(.toggleFeedTapped).value
        await store.send(.appEnteredBackground).value
        await store.send(.appBecameActive).value

        #expect(feed.startCount == 1)
        #expect(feed.suspendCount == 1)
        #expect(feed.resumeCount == 1)
    }

    @Test func stateIsUpdatedBeforeSendReturns() {
        let store = makeStore()

        store.send(.sortOrderChanged(.priceChange))

        #expect(store.sortOrder == .priceChange)
    }

    @Test func loadingFetchesSymbolsAndTracksThem() async {
        repository.result = .success(symbols)
        let store = makeStore()

        await store.send(.loadSymbols).value

        #expect(store.symbols == symbols)
        #expect(!store.isLoadingSymbols)
        #expect(feed.trackedSymbols == symbols)
    }

    @Test func failedFetchRaisesTheAlert() async {
        repository.result = .failure(TestError())
        let store = makeStore()

        await store.send(.loadSymbols).value

        #expect(store.alert == .symbolsUnavailable)
        #expect(!store.isLoadingSymbols)
    }

    @Test func refreshReconnectsAndWaitsForTheReload() async {
        repository.result = .success(symbols)
        let store = makeStore()

        await store.send(.refreshRequested).value

        #expect(feed.reconnectCount == 1)
        #expect(store.symbols == symbols)
    }

    @Test func feedEventsBecomeActions() async {
        repository.result = .success(symbols)
        let store = makeStore()
        await store.send(.loadSymbols).value
        feed.continuation.yield(.connectionChanged(.connected))
        feed.continuation.yield(.priceUpdates([PriceUpdate(symbol: "BBB", price: 33)]))
        feed.continuation.finish()

        await store.observeFeed()

        #expect(store.connectionState == .connected)
        #expect(store.state.quote(for: symbols[1]) == StockQuote(price: 33, change: 3))
    }
}
