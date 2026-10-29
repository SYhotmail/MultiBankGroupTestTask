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
/// Records the issues a view model reports.
@MainActor
final class IssueRecorder {
    private(set) var issues: [(issue: StockSymbolsIssue, debugDescription: String)] = []

    var handler: StockSymbolsIssueHandler {
        { [self] issue, reason in issues.append((issue, reason)) }
    }
}

/// A list view model over a real `StockMarketModel`, the fake provider and the fake feed.
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
    let list: StockSymbolsListViewModel
    let issues = IssueRecorder()

    init() {
        provider = FakeStockSymbolsProvider(result: .success(catalog))
        market = StockMarketModel(feed: feed)
        list = StockSymbolsListViewModel(provider: provider, market: market, feed: feed)
        list.onIssue = issues.handler
    }

    func load() async {
        await list.load()
    }

    func detail(_ index: Int) -> StockSymbolDetailViewModel {
        StockSymbolDetailViewModel(symbol: catalog[index].symbol, list: list, provider: provider, market: market, feed: feed, onIssue: issues.handler)
    }
}

@MainActor
struct StockSymbolsListViewModelTests {
    @Test func loadListsTheSymbolsAndPricesThem() async {
        let fixture = Fixture()

        await fixture.load()

        #expect(fixture.list.symbols == fixture.catalog.map(\.symbol))
        #expect(await fixture.feed.trackedSymbols == fixture.catalog)
        #expect(fixture.market.quote(for: "AAA") == StockQuote(price: 10, updatedAt: .referenceFixture))
        #expect(!fixture.list.isLoading)
    }

    @Test func rowsSortByPriceDescendingByDefault() async {
        let fixture = Fixture()
        await fixture.load()

        #expect(fixture.list.sortOrder == .price)
        #expect(fixture.list.rows.map(\.id) == ["BBB", "CCC", "AAA"])
    }

    @Test func rowsSortByPriceChangeWithTickerTieBreak() async {
        let fixture = Fixture()
        await fixture.load()
        fixture.market.apply(.priceUpdates([
            PriceUpdate(symbol: "AAA", price: 11, timestamp: .fixture),   // +1
            PriceUpdate(symbol: "BBB", price: 29, timestamp: .fixture),   // -1
        ]))

        fixture.list.sortOrder = .priceChange

        // CCC is unchanged (0) and sits between the riser and the faller.
        #expect(fixture.list.rows.map(\.id) == ["AAA", "CCC", "BBB"])
    }

    @Test func rowsCarryLiveQuotes() async {
        let fixture = Fixture()
        await fixture.load()

        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12, timestamp: .fixture)]))

        #expect(fixture.list.rows.first { $0.id == "AAA" }?.quote == StockQuote(price: 12, change: 2, updatedAt: .fixture))
    }

    @Test func loadIfNeededLoadsOnlyOnce() async {
        let fixture = Fixture()

        await fixture.list.loadIfNeeded()
        await fixture.provider.setResult(.success([]))
        await fixture.list.loadIfNeeded()

        #expect(fixture.list.rows.count == 3)
        #expect(!fixture.list.showsLoadingIndicator)
    }

    @Test func refreshReconnectsAndReloads() async {
        let fixture = Fixture()
        await fixture.load()
        await fixture.provider.setResult(.success([fixture.catalog[0]]))

        await fixture.list.refresh()

        #expect(await fixture.feed.reconnectCount == 1)
        #expect(fixture.list.rows.map(\.id) == ["AAA"])
    }

    @Test func reloadKeepsLiveQuotesOfRemainingSymbolsAndAddsNewOnes() async {
        let fixture = Fixture()
        await fixture.load()
        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 15, timestamp: .fixture)]))
        await fixture.provider.setResult(.success([fixture.catalog[0], .fixture("DDD", price: 5)]))

        await fixture.load()

        #expect(fixture.list.symbols.map(\.ticker) == ["AAA", "DDD"])
        #expect(fixture.market.quote(for: "AAA") == StockQuote(price: 15, change: 5, updatedAt: .fixture))
        #expect(fixture.market.quote(for: "BBB") == nil)
        #expect(fixture.market.quote(for: "DDD") == StockQuote(price: 5, updatedAt: .referenceFixture))
    }

    @Test func duplicateTickersKeepTheFirstOccurrence() async {
        let fixture = Fixture()
        await fixture.provider.setResult(.success([.fixture("AAA", price: 1), .fixture("AAA", price: 2)]))

        await fixture.load()

        #expect(fixture.list.symbols.map(\.ticker) == ["AAA"])
        #expect(fixture.market.quote(for: "AAA")?.price == 1)
    }

    @Test func failedLoadReportsAnIssueAndKeepsTheList() async {
        let fixture = Fixture()
        await fixture.load()
        await fixture.provider.setResult(.failure(TestError()))

        await fixture.load()

        #expect(fixture.issues.issues.map(\.issue) == [.symbolsUnavailable])
        #expect(fixture.issues.issues.first?.debugDescription.contains("TestError") == true)
        #expect(fixture.list.symbols == fixture.catalog.map(\.symbol))
        #expect(!fixture.list.isLoading)
    }

    @Test func replaceUpdatesAListedSymbolsDetails() async {
        let fixture = Fixture()
        await fixture.load()

        fixture.list.replace(StockSymbol(ticker: "BBB", name: "BBB Holdings", summary: ""))
        fixture.list.replace(StockSymbol(ticker: "ZZZ", name: "Not listed", summary: ""))

        #expect(fixture.list.symbol(ticker: "BBB")?.name == "BBB Holdings")
        #expect(fixture.list.symbol(ticker: "ZZZ") == nil)
    }

    @Test func removeDropsTheSymbolAndStopsPricingIt() async {
        let fixture = Fixture()
        await fixture.load()

        await fixture.list.remove(ticker: "BBB")

        #expect(fixture.list.symbols.map(\.ticker) == ["AAA", "CCC"])
        #expect(fixture.market.quote(for: "BBB") == nil)
        #expect(await fixture.feed.trackedSymbols.map(\.symbol.ticker) == ["AAA", "CCC"])
    }

    // MARK: - Feed controls (BaseViewModel)

    @Test(arguments: [ConnectionState.connecting, .connected])
    func toggleStopsARunningFeed(state: ConnectionState) async {
        let fixture = Fixture()
        fixture.market.apply(.connectionChanged(state))

        await fixture.list.toggleFeed()

        #expect(await fixture.feed.stopCount == 1)
        #expect(await fixture.feed.startCount == 0)
    }

    @Test func reconnectFeedReachesTheFeed() async {
        let fixture = Fixture()

        await fixture.list.reconnectFeed()

        #expect(await fixture.feed.reconnectCount == 1)
    }

    @Test func toggleAndConnectionStateGoThroughTheMarket() async {
        let fixture = Fixture()

        await fixture.list.toggleFeed()
        fixture.market.apply(.connectionChanged(.connected))

        #expect(await fixture.feed.startCount == 1)
        #expect(fixture.list.connectionState == .connected)
    }
}

@MainActor
struct StockSymbolDetailViewModelTests {
    @Test func quoteFollowsLiveUpdates() async {
        let fixture = Fixture()
        await fixture.load()
        let detail = fixture.detail(1)
        #expect(detail.quote == StockQuote(price: 30, updatedAt: .referenceFixture))

        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "BBB", price: 27, timestamp: .fixture)]))

        #expect(detail.quote == StockQuote(price: 27, change: -3, updatedAt: .fixture))
    }

    @Test func refreshUpdatesTheDetailsInTheList() async {
        let fixture = Fixture()
        await fixture.load()
        let detail = fixture.detail(1)
        await fixture.provider.setSymbolResult(.success(.fixture("BBB", name: "BBB Holdings", price: 30)))

        await detail.refresh()

        #expect(detail.symbol.name == "BBB Holdings")
        #expect(fixture.list.symbol(ticker: "BBB")?.name == "BBB Holdings")
        #expect(await fixture.feed.reconnectCount == 1)
    }

    @Test func refreshTakesANewerPrice() async {
        let fixture = Fixture()
        await fixture.load()
        await fixture.provider.setSymbolResult(.success(.fixture("BBB", price: 33, at: .fixture)))

        await fixture.detail(1).refresh()

        #expect(fixture.market.quote(for: "BBB") == StockQuote(price: 33, change: 3, updatedAt: .fixture))
    }

    @Test func refreshKeepsANewerLiveQuote() async {
        let fixture = Fixture()
        await fixture.load()
        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "BBB", price: 31, timestamp: .fixture)]))
        // The backend's price is older than the live update.
        await fixture.provider.setSymbolResult(.success(.fixture("BBB", price: 99, at: .referenceFixture)))

        await fixture.detail(1).refresh()

        #expect(fixture.market.quote(for: "BBB") == StockQuote(price: 31, change: 1, updatedAt: .fixture))
    }

    @Test func refreshIgnoresAResponseForAnotherSymbol() async {
        let fixture = Fixture()
        await fixture.load()
        await fixture.provider.setSymbolResult(.success(.fixture("CCC", name: "Wrong", price: 1, at: .fixture)))

        await fixture.detail(1).refresh()

        #expect(fixture.list.symbols == fixture.catalog.map(\.symbol))
        #expect(fixture.market.quote(for: "CCC") == StockQuote(price: 20, updatedAt: .referenceFixture))
    }

    @Test func notFoundDeletesTheSymbolWithoutAnIssue() async {
        let fixture = Fixture()
        await fixture.load()
        let detail = fixture.detail(1)
        await fixture.provider.setSymbolResult(.failure(StockSymbolsProviderError.notFound(id: "BBB")))

        await detail.refresh()

        #expect(fixture.list.symbol(ticker: "BBB") == nil)
        #expect(detail.quote == nil)
        #expect(await fixture.feed.trackedSymbols.map(\.symbol.ticker) == ["AAA", "CCC"])
        #expect(fixture.issues.issues.isEmpty)
    }

    @Test func otherFailuresReportAnIssue() async {
        let fixture = Fixture()
        await fixture.load()
        await fixture.provider.setSymbolResult(.failure(TestError()))

        await fixture.detail(1).refresh()

        #expect(fixture.issues.issues.map(\.issue) == [.symbolUnavailable(ticker: "BBB")])
        #expect(fixture.issues.issues.first?.debugDescription.contains("TestError") == true)
        #expect(fixture.list.symbols == fixture.catalog.map(\.symbol))
    }

    @Test func toggleStopsARunningFeed() async {
        let fixture = Fixture()
        fixture.market.apply(.connectionChanged(.connected))

        await fixture.detail(0).toggleFeed()

        #expect(await fixture.feed.stopCount == 1)
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

    @Test func anUnseenAlertIsNotReplaced() async {
        let fixture = NavigationFixture()
        await fixture.deliver([.connectionLost(reason: "first")])
        await fixture.provider.setResult(.failure(TestError()))

        await fixture.viewModel.listViewModel.load()

        #expect(fixture.viewModel.alert == .connectionLost)
        #expect(fixture.viewModel.alertDebugDescription == "first")
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

        // The hooks start their own task, so wait for the feed to receive the calls.
        fixture.viewModel.appDidEnterBackground()
        #expect(await eventually { await fixture.feed.suspendCount == 1 })
        fixture.viewModel.appDidBecomeActive()
        #expect(await eventually { await fixture.feed.resumeCount == 1 })
    }
}
