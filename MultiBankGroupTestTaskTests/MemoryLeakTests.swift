//
//  MemoryLeakTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// Guards against retain cycles: once the root view model is released, everything it created must be
/// released too. The model is private, so its release is checked through the feed: the model is the
/// feed's only owner, so a released feed means a released model.
@MainActor
struct MemoryLeakTests {
    @Test func releasingTheNavigationViewModelReleasesEverything() async {
        weak var weakNavigation: StockSymbolsNavigationViewModel?
        weak var weakList: StockSymbolsListViewModel?
        weak var weakDetail: StockSymbolDetailViewModel?
        weak var weakFeed: FakePriceFeed?

        do {
            let feed = FakePriceFeed()
            let provider = FakeStockSymbolsProvider(result: .success([.fixture("AAA", price: 10)]))
            let navigation = StockSymbolsNavigationViewModel(provider: provider, feed: feed)

            // Use the graph the way the app does before letting it go.
            await navigation.listViewModel.loadIfNeeded()
            navigation.selectedTicker = "AAA"
            let detail = navigation.detailViewModel(for: .fixture("AAA"))
            await detail.refresh()
            await detail.toggleFeed()
            feed.continuation.yield(.priceUpdates([PriceUpdate(symbol: "AAA", price: 11, timestamp: .fixture)]))
            feed.continuation.yield(.connectionLost(reason: "test"))
            feed.continuation.finish()
            await navigation.observeFeed()
            #expect(navigation.alert == .connectionLost)

            weakNavigation = navigation
            weakList = navigation.listViewModel
            weakDetail = detail
            weakFeed = feed
        }

        #expect(weakNavigation == nil, "StockSymbolsNavigationViewModel leaked")
        #expect(weakList == nil, "StockSymbolsListViewModel leaked")
        #expect(weakDetail == nil, "StockSymbolDetailViewModel leaked")
        #expect(weakFeed == nil, "StockMarketModel or its feed leaked")
    }
}
