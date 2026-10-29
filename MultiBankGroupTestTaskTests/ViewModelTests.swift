//
//  ViewModelTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// Shared setup: a real `StockMarketModel` over a fake feed and repository, so view models are
/// tested against the same model the app uses.
@MainActor
private struct Fixture {
    let symbols: [StockSymbol] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]
    let feed = FakePriceFeed()
    let repository: FakeSymbolsRepository
    let market: StockMarketModel

    init() {
        repository = FakeSymbolsRepository(result: .success(symbols))
        market = StockMarketModel(repository: repository, feed: feed)
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
        await fixture.repository.setResult(.success([]))
        await viewModel.loadIfNeeded()

        #expect(viewModel.rows.count == 3)
        #expect(!viewModel.showsLoadingIndicator)
    }

    @Test func refreshReconnectsAndReloads() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolsListViewModel(market: fixture.market)
        await fixture.repository.setResult(.success([fixture.symbols[0]]))

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
        let viewModel = StockSymbolDetailViewModel(symbol: fixture.symbols[1], market: fixture.market)
        #expect(viewModel.quote == StockQuote(price: 30))

        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "BBB", price: 27, timestamp: .fixture)]))

        #expect(viewModel.quote == StockQuote(price: 27, change: -3, updatedAt: .fixture))
    }

    @Test func toggleStopsARunningFeed() async {
        let fixture = Fixture()
        fixture.market.apply(.connectionChanged(.connected))
        let viewModel = StockSymbolDetailViewModel(symbol: fixture.symbols[0], market: fixture.market)

        await viewModel.toggleFeed()

        #expect(await fixture.feed.stopCount == 1)
        #expect(viewModel.connectionState == .connected)
    }
}

@MainActor
struct StockSymbolsNavigationViewModelTests {
    @Test func alertMirrorsTheModelIssue() {
        let fixture = Fixture()
        let viewModel = StockSymbolsNavigationViewModel(market: fixture.market)
        #expect(viewModel.alert == nil)

        fixture.market.apply(.connectionLost)

        #expect(viewModel.alert == .connectionLost)
    }

    @Test func dismissClearsTheIssue() {
        let fixture = Fixture()
        fixture.market.apply(.connectionLost)
        let viewModel = StockSymbolsNavigationViewModel(market: fixture.market)

        viewModel.dismissAlert()

        #expect(fixture.market.issue == nil)
    }

    @Test func retryingASymbolsIssueReloads() async {
        let fixture = Fixture()
        await fixture.repository.setResult(.failure(TestError()))
        await fixture.load()
        let viewModel = StockSymbolsNavigationViewModel(market: fixture.market)
        await fixture.repository.setResult(.success(fixture.symbols))

        await viewModel.retry(.symbolsUnavailable)

        #expect(viewModel.alert == nil)
        #expect(fixture.market.symbols == fixture.symbols)
    }

    @Test func retryingAConnectionIssueReconnects() async {
        let fixture = Fixture()
        fixture.market.apply(.connectionLost)
        let viewModel = StockSymbolsNavigationViewModel(market: fixture.market)

        await viewModel.retry(.connectionLost)

        #expect(viewModel.alert == nil)
        #expect(await fixture.feed.reconnectCount == 1)
    }

    @Test func detailViewModelsShareTheModel() async {
        let fixture = Fixture()
        await fixture.load()
        let viewModel = StockSymbolsNavigationViewModel(market: fixture.market)
        let detail = viewModel.detailViewModel(for: fixture.symbols[0])

        fixture.market.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 9, timestamp: .fixture)]))

        #expect(detail.quote.price == 9)
        #expect(viewModel.listViewModel.rows.first { $0.id == "AAA" }?.quote.price == 9)
    }
}
