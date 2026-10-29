//
//  StockMarketModelTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// The shared live connection: live quotes, connection state and which symbols are priced.
@MainActor
struct StockMarketModelTests {
    private let feed = FakePriceFeed()
    private let catalog: [StockSymbolPrice] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]

    /// A model pricing `catalog`.
    private func makeModel() async -> StockMarketModel {
        let model = StockMarketModel(feed: feed)
        await model.track(catalog)
        return model
    }

    // MARK: - Tracking

    @Test func trackingStartsQuotesAtTheGivenPrices() async {
        let model = await makeModel()

        #expect(model.quote(for: "AAA") == StockQuote(price: 10, updatedAt: .referenceFixture))
        #expect(await feed.trackedSymbols == catalog)
    }

    @Test func retrackingKeepsLiveQuotesAddsNewAndDropsMissing() async {
        let model = await makeModel()
        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 15, timestamp: .fixture)]))

        await model.track([catalog[0], .fixture("DDD", price: 5)])

        #expect(model.quote(for: "AAA") == StockQuote(price: 15, change: 5, updatedAt: .fixture))
        #expect(model.quote(for: "DDD") == StockQuote(price: 5, updatedAt: .referenceFixture))
        #expect(model.quote(for: "BBB") == nil)
    }

    @Test func duplicateTickersKeepTheFirstOccurrence() async {
        let model = StockMarketModel(feed: feed)

        await model.track([.fixture("AAA", price: 1), .fixture("AAA", price: 2)])

        #expect(model.quote(for: "AAA")?.price == 1)
        #expect(await feed.trackedSymbols.count == 1)
    }

    @Test func untrackStopsPricingASymbol() async {
        let model = await makeModel()

        await model.untrack(ticker: "BBB")

        #expect(model.quote(for: "BBB") == nil)
        #expect(await feed.trackedSymbols.map(\.symbol.ticker) == ["AAA", "CCC"])
    }

    // MARK: - Prices

    @Test func priceUpdateRecordsNewPriceAndChange() async {
        let model = await makeModel()

        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12.5, timestamp: .fixture)]))
        #expect(model.quote(for: "AAA") == StockQuote(price: 12.5, change: 2.5, updatedAt: .fixture))
        #expect(model.quote(for: "AAA")?.direction == .up)

        model.apply(.priceUpdates([PriceUpdate(symbol: "AAA", price: 11, timestamp: .fixture)]))
        #expect(model.quote(for: "AAA") == StockQuote(price: 11, change: -1.5, updatedAt: .fixture))
        #expect(model.quote(for: "AAA")?.direction == .down)
    }

    @Test func updatesForUntrackedSymbolsAreIgnored() async {
        let model = await makeModel()
        let before = model.quotes

        model.apply(.priceUpdates([PriceUpdate(symbol: "ZZZ", price: 1, timestamp: .fixture)]))

        #expect(model.quotes == before)
    }

    @Test func applyIfNewerTakesANewerPrice() async {
        let model = await makeModel()

        model.applyIfNewer(.fixture("BBB", price: 33, at: .fixture))

        #expect(model.quote(for: "BBB") == StockQuote(price: 33, change: 3, updatedAt: .fixture))
    }

    @Test func applyIfNewerIgnoresAnOlderPrice() async {
        let model = await makeModel()
        model.apply(.priceUpdates([PriceUpdate(symbol: "BBB", price: 31, timestamp: .fixture)]))

        model.applyIfNewer(.fixture("BBB", price: 99, at: .referenceFixture))

        #expect(model.quote(for: "BBB") == StockQuote(price: 31, change: 1, updatedAt: .fixture))
    }

    // MARK: - Connection

    @Test func connectionChangeIsRecorded() async {
        let model = await makeModel()

        model.apply(.connectionChanged(.connected))

        #expect(model.connectionState == .connected)
        #expect(model.isFeedRunning)
    }

    @Test func connectionLostIsReportedWithItsReason() async {
        let model = await makeModel()
        var reasons: [String] = []
        model.onConnectionLost = { reasons.append($0) }

        model.apply(.connectionLost(reason: "socket closed"))

        #expect(reasons == ["socket closed"])
    }

    @Test func observeFeedAppliesEventsInOrder() async {
        let model = await makeModel()
        feed.continuation.yield(.connectionChanged(.connected))
        feed.continuation.yield(.priceUpdates([PriceUpdate(symbol: "CCC", price: 25, timestamp: .fixture)]))
        feed.continuation.finish()

        await model.observeFeed()

        #expect(model.connectionState == .connected)
        #expect(model.quote(for: "CCC") == StockQuote(price: 25, change: 5, updatedAt: .fixture))
    }
}
