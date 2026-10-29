//
//  StockMarketModelTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

@MainActor
struct StockMarketModelTests {
    private let feed = FakePriceFeed()
    private let provider = FakeStockSymbolsProvider()
    private let catalog: [StockSymbolPrice] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]

    /// A model with `catalog` already loaded.
    private func makeModel() async -> StockMarketModel {
        await provider.setResult(.success(catalog))
        let model = StockMarketModel(provider: provider, feed: feed)
        await model.loadSymbols()
        return model
    }

    @Test func startsWithReferencePricesAndNoChange() async {
        let model = await makeModel()
        #expect(model.quote(for: catalog[0].symbol) == StockQuote(price: 10, updatedAt: .referenceFixture))
        #expect(model.connectionState == .disconnected)
    }

    @Test func priceUpdateRecordsNewPriceAndChange() async {
        let model = await makeModel()

        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12.5, timestamp: .fixture)]))
        #expect(model.quote(for: catalog[0].symbol) == StockQuote(price: 12.5, change: 2.5, updatedAt: .fixture))
        #expect(model.quote(for: catalog[0].symbol)?.direction == .up)

        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 11, timestamp: .fixture)]))
        #expect(model.quote(for: catalog[0].symbol) == StockQuote(price: 11, change: -1.5, updatedAt: .fixture))
        #expect(model.quote(for: catalog[0].symbol)?.direction == .down)
    }

    @Test func updatesForUnknownSymbolsAreIgnored() async {
        let model = await makeModel()
        let before = model.quotes

        model.apply(.priceUpdates([PriceUpdate(symbol: "ZZZ", price: 1, timestamp: .fixture)]))

        #expect(model.quotes == before)
    }

    @Test(arguments: [ConnectionState.connecting, .connected])
    func toggleStopsARunningFeed(state: ConnectionState) async {
        let model = await makeModel()
        model.apply(.connectionChanged(state))

        await model.toggleFeed()

        #expect(await feed.stopCount == 1)
        #expect(await feed.startCount == 0)
    }

    @Test func toggleStartsAStoppedFeed() async {
        let model = await makeModel()

        await model.toggleFeed()

        #expect(await feed.startCount == 1)
        #expect(await feed.stopCount == 0)
    }

    @Test func appLifecycleSuspendsAndResumesTheFeed() async {
        let model = await makeModel()

        await model.appDidEnterBackground()
        await model.appDidBecomeActive()

        #expect(await feed.suspendCount == 1)
        #expect(await feed.resumeCount == 1)
    }

    @Test func observeFeedAppliesEventsInOrder() async {
        let model = await makeModel()
        feed.continuation.yield(.connectionChanged(.connected))
        feed.continuation.yield(.priceUpdates([PriceUpdate(symbol: "CCC", price: 25, timestamp: .fixture)]))
        feed.continuation.finish()

        await model.observeFeed()

        #expect(model.connectionState == .connected)
        #expect(model.quote(for: catalog[2].symbol) == StockQuote(price: 25, change: 5, updatedAt: .fixture))
    }

    @Test func loadingSymbolsTracksThemInTheFeed() async {
        _ = await makeModel()
        #expect(await feed.trackedSymbols == catalog)
    }

    @Test func reloadKeepsQuotesOfRemainingSymbolsAndAddsNewOnes() async {
        let model = await makeModel()
        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 15, timestamp: .fixture)]))
        await provider.setResult(.success([catalog[0], .fixture("DDD", price: 5)]))

        await model.loadSymbols()

        #expect(model.symbols.map(\.ticker) == ["AAA", "DDD"])
        #expect(model.quote(for: catalog[0].symbol) == StockQuote(price: 15, change: 5, updatedAt: .fixture))
        #expect(model.quotes["BBB"] == nil)
        #expect(model.quotes["DDD"] == StockQuote(price: 5, updatedAt: .referenceFixture))
    }

    @Test func duplicateTickersKeepTheFirstOccurrence() async {
        await provider.setResult(.success([.fixture("AAA", price: 1), .fixture("AAA", price: 2)]))
        let model = StockMarketModel(provider: provider, feed: feed)

        await model.loadSymbols()

        #expect(model.symbols.map(\.ticker) == ["AAA"])
        #expect(model.quotes["AAA"]?.price == 1)
    }

    @Test func failedLoadRaisesIssueAndKeepsCurrentSymbols() async {
        let model = await makeModel()
        await provider.setResult(.failure(TestError()))

        await model.loadSymbols()

        #expect(model.issue == .symbolsUnavailable)
        #expect(model.symbols == catalog.map(\.symbol))
        #expect(!model.isLoadingSymbols)
    }

    @Test func refreshReconnectsFeedAndReloadsSymbols() async {
        let model = await makeModel()
        await provider.setResult(.success([catalog[2]]))

        await model.refresh()

        #expect(await feed.reconnectCount == 1)
        #expect(model.symbols == [catalog[2].symbol])
    }

    @Test func connectionLostDoesNotReplaceAnUnseenIssue() async {
        let model = await makeModel()
        await provider.setResult(.failure(TestError()))
        await model.loadSymbols()

        model.apply(.connectionLost)

        #expect(model.issue == .symbolsUnavailable)
    }

    @Test func connectionLostRaisesIssue() async {
        let model = await makeModel()
        model.apply(.connectionLost)
        #expect(model.issue == .connectionLost)
    }

    @Test func clearIssueRemovesIt() async {
        let model = await makeModel()
        model.apply(.connectionLost)

        model.clearIssue()

        #expect(model.issue == nil)
    }

    // MARK: - Single-symbol refresh

    @Test func refreshSymbolUpdatesItsDetails() async {
        let model = await makeModel()
        await provider.setSymbolResult(.success(.fixture("BBB", name: "BBB Holdings", price: 30)))

        await model.refreshSymbol(ticker: "BBB")

        #expect(model.symbol(ticker: "BBB")?.name == "BBB Holdings")
        #expect(model.symbols.map(\.ticker) == ["AAA", "BBB", "CCC"])
    }

    @Test func refreshSymbolTakesANewerPrice() async {
        let model = await makeModel()
        await provider.setSymbolResult(.success(.fixture("BBB", price: 33, at: .fixture)))

        await model.refreshSymbol(ticker: "BBB")

        #expect(model.quotes["BBB"] == StockQuote(price: 33, change: 3, updatedAt: .fixture))
    }

    @Test func refreshSymbolKeepsANewerLiveQuote() async {
        let model = await makeModel()
        model.apply(.priceUpdates([PriceUpdate(symbol: "BBB", price: 31, timestamp: .fixture)]))
        // The backend's price is older than the live update.
        await provider.setSymbolResult(.success(.fixture("BBB", price: 99, at: .referenceFixture)))

        await model.refreshSymbol(ticker: "BBB")

        #expect(model.quotes["BBB"] == StockQuote(price: 31, change: 1, updatedAt: .fixture))
    }

    @Test func refreshSymbolIgnoresAResponseForAnotherSymbol() async {
        let model = await makeModel()
        await provider.setSymbolResult(.success(.fixture("CCC", name: "Wrong", price: 1, at: .fixture)))

        await model.refreshSymbol(ticker: "BBB")

        #expect(model.symbols == catalog.map(\.symbol))
        #expect(model.quotes["CCC"] == StockQuote(price: 20, updatedAt: .referenceFixture))
    }

    @Test func refreshSymbolFailureRaisesIssueAndKeepsData() async {
        let model = await makeModel()
        await provider.setSymbolResult(.failure(TestError()))

        await model.refreshSymbol(ticker: "BBB")

        #expect(model.issue == .symbolUnavailable(ticker: "BBB"))
        #expect(model.symbols == catalog.map(\.symbol))
    }

    @Test func refreshSymbolNotFoundRemovesTheSymbol() async {
        let model = await makeModel()
        await provider.setSymbolResult(.failure(StockSymbolsProviderError.notFound(id: "BBB")))

        await model.refreshSymbol(ticker: "BBB")

        #expect(model.symbols.map(\.ticker) == ["AAA", "CCC"])
        #expect(model.quotes["BBB"] == nil)
        #expect(await feed.trackedSymbols.map(\.symbol.ticker) == ["AAA", "CCC"])
        // A deletion is not an error.
        #expect(model.issue == nil)
    }
}
