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
    private let repository = FakeSymbolsRepository()
    private let symbols: [StockSymbol] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]

    /// A model with `symbols` already loaded.
    private func makeModel() async -> StockMarketModel {
        repository.result = .success(symbols)
        let model = StockMarketModel(repository: repository, feed: feed)
        await model.loadSymbols()
        return model
    }

    @Test func startsWithReferencePricesAndNoChange() async {
        let model = await makeModel()
        #expect(model.quote(for: symbols[0]) == StockQuote(price: 10, change: 0))
        #expect(model.connectionState == .disconnected)
    }

    @Test func priceUpdateRecordsNewPriceAndChange() async {
        let model = await makeModel()

        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12.5)]))
        #expect(model.quote(for: symbols[0]) == StockQuote(price: 12.5, change: 2.5))
        #expect(model.quote(for: symbols[0]).direction == .up)

        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 11)]))
        #expect(model.quote(for: symbols[0]) == StockQuote(price: 11, change: -1.5))
        #expect(model.quote(for: symbols[0]).direction == .down)
    }

    @Test func updatesForUnknownSymbolsAreIgnored() async {
        let model = await makeModel()
        let before = model.quotes

        model.apply(.priceUpdates([PriceUpdate(symbol: "ZZZ", price: 1)]))

        #expect(model.quotes == before)
    }

    @Test(arguments: [ConnectionState.connecting, .connected])
    func toggleStopsARunningFeed(state: ConnectionState) async {
        let model = await makeModel()
        model.apply(.connectionChanged(state))

        model.toggleFeed()

        #expect(feed.stopCount == 1)
        #expect(feed.startCount == 0)
    }

    @Test func toggleStartsAStoppedFeed() async {
        let model = await makeModel()

        model.toggleFeed()

        #expect(feed.startCount == 1)
        #expect(feed.stopCount == 0)
    }

    @Test func appLifecycleSuspendsAndResumesTheFeed() async {
        let model = await makeModel()

        model.appDidEnterBackground()
        model.appDidBecomeActive()

        #expect(feed.suspendCount == 1)
        #expect(feed.resumeCount == 1)
    }

    @Test func observeFeedAppliesEventsInOrder() async {
        let model = await makeModel()
        feed.continuation.yield(.connectionChanged(.connected))
        feed.continuation.yield(.priceUpdates([PriceUpdate(symbol: "CCC", price: 25)]))
        feed.continuation.finish()

        await model.observeFeed()

        #expect(model.connectionState == .connected)
        #expect(model.quote(for: symbols[2]) == StockQuote(price: 25, change: 5))
    }

    @Test func loadingSymbolsTracksThemInTheFeed() async {
        _ = await makeModel()
        #expect(feed.trackedSymbols == symbols)
    }

    @Test func reloadKeepsQuotesOfRemainingSymbolsAndAddsNewOnes() async {
        let model = await makeModel()
        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 15)]))
        repository.result = .success([symbols[0], .fixture("DDD", price: 5)])

        await model.loadSymbols()

        #expect(model.symbols.map(\.ticker) == ["AAA", "DDD"])
        #expect(model.quote(for: symbols[0]) == StockQuote(price: 15, change: 5))
        #expect(model.quotes["BBB"] == nil)
        #expect(model.quotes["DDD"] == StockQuote(price: 5))
    }

    @Test func duplicateTickersKeepTheFirstOccurrence() async {
        let model = await makeModel()
        repository.result = .success([.fixture("AAA", price: 1), .fixture("AAA", price: 2)])

        await model.loadSymbols()

        #expect(model.symbols.count == 1)
        #expect(model.symbols.first?.referencePrice == 1)
    }

    @Test func failedLoadRaisesIssueAndKeepsCurrentSymbols() async {
        let model = await makeModel()
        repository.result = .failure(TestError())

        await model.loadSymbols()

        #expect(model.issue == .symbolsUnavailable)
        #expect(model.symbols == symbols)
        #expect(!model.isLoadingSymbols)
    }

    @Test func refreshReconnectsFeedAndReloadsSymbols() async {
        let model = await makeModel()
        repository.result = .success([symbols[2]])

        await model.refresh()

        #expect(feed.reconnectCount == 1)
        #expect(model.symbols == [symbols[2]])
    }

    @Test func connectionLostDoesNotReplaceAnUnseenIssue() async {
        let model = await makeModel()
        repository.result = .failure(TestError())
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
}
