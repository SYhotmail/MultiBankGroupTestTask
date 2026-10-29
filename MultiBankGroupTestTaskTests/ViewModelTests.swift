//
//  ViewModelTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// Shared setup: a real `StockMarketModel` over a fake feed and provider, so view models are
/// tested against the same model the app uses.
@MainActor
private struct Fixture {
    let catalog: [StockSymbolPrice] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]
    let feed = FakePriceFeed()
    let provider: FakeStockSymbolsProvider
    let market: StockMarketModel

    init() {
        provider = FakeStockSymbolsProvider(result: .success(catalog))
        market = StockMarketModel(provider: provider, feed: feed)
    }

    func load() async {
        await market.loadSymbols()
    }
}

@MainActor
struct StockSymbolsListViewModelTests {
    @Test func rowsSortByPriceDescendingByDefault() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolsListViewModel(market: fixture.market)

        #expect(viewModel.sortOrder == .price)
        #expect(viewModel.rows.map(\.id) == ["BBB", "CCC", "AAA"])
    }

    @Test func rowsSortByPriceChangeWithTickerTieBreak() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolsListViewModel(market: fixture.market)
        fixture.market.apply(.priceUpdates([
            PriceUpdate(symbol: "AAA", price: 11, timestamp: .fixture),   // +1
            PriceUpdate(symbol: "BBB", price: 29, timestamp: .fixture),   // -1
        ]))

        viewModel.sortOrder = .priceChange

        // CCC is unchanged (0) and sits between the riser and the faller.
        #expect(viewModel.rows.map(\.id) == ["AAA", "CCC", "BBB"])
    }

    @Test func rowsCarryLiveQuotes() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolsListViewModel(market: fixture.market)

        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12, timestamp: .fixture)]))

        #expect(viewModel.rows.first { $0.id == "AAA" }?.quote == StockQuote(price: 12, change: 2, updatedAt: .fixture))
    }

    @Test func loadIfNeededLoadsOnlyOnce() async {
        let fixture = Fixture()
        let viewModel = StockSymbolsListViewModel(market: fixture.market)

        await viewModel.loadIfNeeded()
        await fixture.provider.setResult(.success([]))
        await viewModel.loadIfNeeded()

        #expect(viewModel.rows.count == 3)
        #expect(!viewModel.showsLoadingIndicator)
    }

    @Test func refreshReconnectsAndReloads() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolsListViewModel(market: fixture.market)
        await fixture.provider.setResult(.success([fixture.catalog[0]]))

        await viewModel.refresh()

        #expect(await fixture.feed.reconnectCount == 1)
        #expect(viewModel.rows.map(\.id) == ["AAA"])
    }

    @Test func toggleAndConnectionStateGoThroughTheModel() async {
        let fixture = Fixture()
        let viewModel = StockSymbolsListViewModel(market: fixture.market)

        await viewModel.toggleFeed()
        fixture.market.apply(.connectionChanged(.connected))

        #expect(await fixture.feed.startCount == 1)
        #expect(viewModel.connectionState == .connected)
    }
}

@MainActor
struct StockSymbolDetailViewModelTests {
    @Test func quoteFollowsLiveUpdates() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolDetailViewModel(symbol: fixture.catalog[1].symbol, market: fixture.market)
        #expect(viewModel.quote == StockQuote(price: 30, updatedAt: .referenceFixture))

        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "BBB", price: 27, timestamp: .fixture)]))

        #expect(viewModel.quote == StockQuote(price: 27, change: -3, updatedAt: .fixture))
    }

    @Test func quoteIsNilOnceARefreshRemovesTheSymbol() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolDetailViewModel(symbol: fixture.catalog[1].symbol, market: fixture.market)
        await fixture.provider.setResult(.success([fixture.catalog[0]]))

        await fixture.market.loadSymbols()

        #expect(viewModel.quote == nil)
    }

    @Test func refreshShowsTheBackendsLatestDetails() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolDetailViewModel(symbol: fixture.catalog[1].symbol, market: fixture.market)
        await fixture.provider.setSymbolResult(.success(.fixture("BBB", name: "BBB Holdings", price: 30)))

        await viewModel.refresh()

        #expect(viewModel.symbol.name == "BBB Holdings")
    }

    @Test func toggleStopsARunningFeed() async {
        let fixture = Fixture()
        fixture.market.apply(.connectionChanged(.connected))
        let viewModel = StockSymbolDetailViewModel(symbol: fixture.catalog[0].symbol, market: fixture.market)

        await viewModel.toggleFeed()

        #expect(await fixture.feed.stopCount == 1)
        #expect(viewModel.connectionState == .connected)
    }
}

/// The navigation view model builds its own `StockMarketModel`, so these tests drive it only through
/// what it's given: the fake provider and the fake feed's event stream.
@MainActor
private struct NavigationFixture {
    let catalog: [StockSymbolPrice] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]
    let feed = FakePriceFeed()
    let provider: FakeStockSymbolsProvider
    let viewModel: StockSymbolsNavigationViewModel

    init() {
        provider = FakeStockSymbolsProvider(result: .success(catalog))
        viewModel = StockSymbolsNavigationViewModel(provider: provider, feed: feed)
    }

    func load() async {
        await viewModel.listViewModel.loadIfNeeded()
    }

    /// Delivers feed events and waits until the view model has applied them. Ends the feed's stream,
    /// so use it once per test.
    func deliver(_ events: [PriceFeedEvent]) async {
        events.forEach { feed.continuation.yield($0) }
        feed.continuation.finish()
        await viewModel.observeFeed()
    }
}

@MainActor
struct StockSymbolsNavigationViewModelTests {
    @Test func alertMirrorsTheModelIssue() async {
        let fixture = NavigationFixture()
        #expect(fixture.viewModel.alert == nil)

        await fixture.deliver([.connectionLost(reason: "test")])

        #expect(fixture.viewModel.alert == .connectionLost)
    }

    @Test func alertDebugDescriptionMirrorsTheModel() async {
        let fixture = NavigationFixture()

        await fixture.deliver([.connectionLost(reason: "socket closed")])

        #expect(fixture.viewModel.alertDebugDescription == "socket closed")
    }

    // MARK: - Selection

    @Test func selectingATickerShowsThatSymbol() async {
        let fixture = NavigationFixture()
        await fixture.load()

        fixture.viewModel.selectedTicker = "BBB"

        #expect(fixture.viewModel.selectedTicker == "BBB")
        #expect(fixture.viewModel.selectedSymbol == fixture.catalog[1].symbol)
    }

    @Test func selectionClearsWhenTheBackendDeletesTheSymbol() async {
        let fixture = NavigationFixture()
        await fixture.load()
        fixture.viewModel.selectedTicker = "BBB"
        await fixture.provider.setSymbolResult(.failure(StockSymbolsProviderError.notFound(id: "BBB")))

        await fixture.viewModel.detailViewModel(for: fixture.catalog[1].symbol).refresh()

        #expect(fixture.viewModel.selectedTicker == nil)
        #expect(fixture.viewModel.selectedSymbol == nil)
    }

    @Test func selectionClearsWhenAListReloadDropsTheSymbol() async {
        let fixture = NavigationFixture()
        await fixture.load()
        fixture.viewModel.selectedTicker = "BBB"
        await fixture.provider.setResult(.success([fixture.catalog[0]]))

        await fixture.viewModel.listViewModel.refresh()

        #expect(fixture.viewModel.selectedTicker == nil)
    }

    @Test func selectionOfAnUnknownTickerReadsAsNil() async {
        let fixture = NavigationFixture()
        await fixture.load()

        fixture.viewModel.selectedTicker = "ZZZ"

        #expect(fixture.viewModel.selectedTicker == nil)
    }

    // MARK: - Alerts

    @Test func dismissClearsTheAlert() async {
        let fixture = NavigationFixture()
        await fixture.deliver([.connectionLost(reason: "test")])

        fixture.viewModel.dismissAlert()

        #expect(fixture.viewModel.alert == nil)
        #expect(fixture.viewModel.alertDebugDescription == nil)
    }

    @Test func retryingASymbolsIssueReloads() async {
        let fixture = NavigationFixture()
        await fixture.provider.setResult(.failure(TestError()))
        await fixture.load()
        #expect(fixture.viewModel.alert == .symbolsUnavailable)
        await fixture.provider.setResult(.success(fixture.catalog))

        await fixture.viewModel.retry(.symbolsUnavailable)

        #expect(fixture.viewModel.alert == nil)
        #expect(fixture.viewModel.listViewModel.rows.count == fixture.catalog.count)
    }

    @Test func retryingASymbolIssueRefreshesThatSymbol() async {
        let fixture = NavigationFixture()
        await fixture.load()
        let detail = fixture.viewModel.detailViewModel(for: fixture.catalog[0].symbol)
        await fixture.provider.setSymbolResult(.failure(TestError()))
        await detail.refresh()
        #expect(fixture.viewModel.alert == .symbolUnavailable(ticker: "AAA"))
        await fixture.provider.setSymbolResult(.success(.fixture("AAA", name: "AAA Group", price: 10)))

        await fixture.viewModel.retry(.symbolUnavailable(ticker: "AAA"))

        #expect(fixture.viewModel.alert == nil)
        #expect(detail.symbol.name == "AAA Group")
    }

    @Test func retryingAConnectionIssueReconnects() async {
        let fixture = NavigationFixture()
        await fixture.deliver([.connectionLost(reason: "test")])

        await fixture.viewModel.retry(.connectionLost)

        #expect(fixture.viewModel.alert == nil)
        #expect(await fixture.feed.reconnectCount == 1)
    }

    // MARK: - Shared model

    @Test func detailAndListViewModelsShareTheModel() async {
        let fixture = NavigationFixture()
        await fixture.load()
        let detail = fixture.viewModel.detailViewModel(for: fixture.catalog[0].symbol)

        await fixture.deliver([.priceUpdates([PriceUpdate(symbol: "AAA", price: 9, timestamp: .fixture)])])

        #expect(detail.quote?.price == 9)
        #expect(fixture.viewModel.listViewModel.rows.first { $0.id == "AAA" }?.quote.price == 9)
    }

    @Test func lifecycleHooksReachTheFeed() async {
        let fixture = NavigationFixture()

        await fixture.viewModel.appDidEnterBackground()
        await fixture.viewModel.appDidBecomeActive()

        #expect(await fixture.feed.suspendCount == 1)
        #expect(await fixture.feed.resumeCount == 1)
    }
}
