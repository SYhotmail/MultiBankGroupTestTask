//
//  AppReducerTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// The reducer is pure, so every test is: given a state and an action, expect a state and effects.
struct AppReducerTests {
    private let symbols: [StockSymbol] = [
        .fixture("AAA", price: 10),
        .fixture("BBB", price: 30),
        .fixture("CCC", price: 20),
    ]

    /// State with `symbols` loaded at their reference prices.
    private func loadedState() -> AppState {
        var state = AppState()
        _ = AppReducer.reduce(&state, .symbolsLoaded(symbols))
        return state
    }

    // MARK: - Feed control

    @Test func toggleStartsAStoppedFeed() {
        var state = AppState()
        #expect(AppReducer.reduce(&state, .toggleFeedTapped) == [.startFeed])
        #expect(state == AppState())
    }

    @Test(arguments: [ConnectionState.connecting, .connected])
    func toggleStopsARunningFeed(connectionState: ConnectionState) {
        var state = AppState(connectionState: connectionState)
        #expect(AppReducer.reduce(&state, .toggleFeedTapped) == [.stopFeed])
    }

    @Test func lifecycleSuspendsAndResumesTheFeed() {
        var state = AppState()
        #expect(AppReducer.reduce(&state, .appEnteredBackground) == [.suspendFeed])
        #expect(AppReducer.reduce(&state, .appBecameActive) == [.resumeFeed])
        #expect(state == AppState())
    }

    @Test func connectionChangeIsRecorded() {
        var state = AppState()
        #expect(AppReducer.reduce(&state, .feed(.connectionChanged(.connected))).isEmpty)
        #expect(state.connectionState == .connected)
        #expect(state.isFeedRunning)
    }

    // MARK: - Symbols

    @Test func loadStartsLoadingAndFetches() {
        var state = AppState()
        #expect(AppReducer.reduce(&state, .loadSymbols) == [.fetchSymbols])
        #expect(state.isLoadingSymbols)
    }

    @Test func refreshReconnectsAndFetches() {
        var state = loadedState()
        #expect(AppReducer.reduce(&state, .refreshRequested) == [.reconnectFeed, .fetchSymbols])
        #expect(state.isLoadingSymbols)
    }

    @Test func loadedSymbolsStartAtReferencePricesAndAreTracked() {
        var state = AppState(isLoadingSymbols: true)

        let effects = AppReducer.reduce(&state, .symbolsLoaded(symbols))

        #expect(effects == [.trackSymbols(symbols)])
        #expect(state.symbols == symbols)
        #expect(state.quote(for: symbols[0]) == StockQuote(price: 10))
        #expect(!state.isLoadingSymbols)
    }

    @Test func reloadKeepsQuotesOfRemainingSymbolsAndAddsNewOnes() {
        var state = loadedState()
        _ = AppReducer.reduce(&state, .feed(.priceUpdates([PriceUpdate(symbol: "AAA", price: 15)])))

        _ = AppReducer.reduce(&state, .symbolsLoaded([symbols[0], .fixture("DDD", price: 5)]))

        #expect(state.symbols.map(\.ticker) == ["AAA", "DDD"])
        #expect(state.quotes == ["AAA": StockQuote(price: 15, change: 5), "DDD": StockQuote(price: 5)])
    }

    @Test func duplicateTickersKeepTheFirstOccurrence() {
        var state = AppState()
        let first = StockSymbol.fixture("AAA", price: 1)

        let effects = AppReducer.reduce(&state, .symbolsLoaded([first, .fixture("AAA", price: 2)]))

        #expect(state.symbols == [first])
        #expect(effects == [.trackSymbols([first])])
    }

    @Test func failedLoadRaisesAlertAndKeepsCurrentSymbols() {
        var state = loadedState()
        state.isLoadingSymbols = true

        #expect(AppReducer.reduce(&state, .symbolsLoadFailed).isEmpty)

        #expect(state.alert == .symbolsUnavailable)
        #expect(state.symbols == symbols)
        #expect(!state.isLoadingSymbols)
    }

    // MARK: - Prices and sorting

    @Test func priceUpdateRecordsNewPriceAndChange() {
        var state = loadedState()

        _ = AppReducer.reduce(&state, .feed(.priceUpdates([PriceUpdate(symbol: "AAA", price: 12.5)])))
        #expect(state.quote(for: symbols[0]) == StockQuote(price: 12.5, change: 2.5))
        #expect(state.quote(for: symbols[0]).direction == .up)

        _ = AppReducer.reduce(&state, .feed(.priceUpdates([PriceUpdate(symbol: "AAA", price: 11)])))
        #expect(state.quote(for: symbols[0]) == StockQuote(price: 11, change: -1.5))
        #expect(state.quote(for: symbols[0]).direction == .down)
    }

    @Test func updatesForUnknownSymbolsAreIgnored() {
        var state = loadedState()
        let before = state

        _ = AppReducer.reduce(&state, .feed(.priceUpdates([PriceUpdate(symbol: "ZZZ", price: 1)])))

        #expect(state == before)
    }

    @Test func sortsByPriceDescending() {
        var state = loadedState()
        _ = AppReducer.reduce(&state, .sortOrderChanged(.price))
        #expect(state.sortedSymbols.map(\.ticker) == ["BBB", "CCC", "AAA"])
    }

    @Test func sortsByPriceChangeDescendingWithTickerTieBreak() {
        var state = loadedState()
        _ = AppReducer.reduce(&state, .feed(.priceUpdates([
            PriceUpdate(symbol: "AAA", price: 11),   // +1
            PriceUpdate(symbol: "BBB", price: 29),   // -1
        ])))

        _ = AppReducer.reduce(&state, .sortOrderChanged(.priceChange))

        // CCC is unchanged (0) and sits between the riser and the faller.
        #expect(state.sortOrder == .priceChange)
        #expect(state.sortedSymbols.map(\.ticker) == ["AAA", "CCC", "BBB"])
    }

    // MARK: - Alerts

    @Test func connectionLostRaisesAlert() {
        var state = AppState()
        #expect(AppReducer.reduce(&state, .feed(.connectionLost)).isEmpty)
        #expect(state.alert == .connectionLost)
    }

    @Test func connectionLostDoesNotReplaceAnUnseenAlert() {
        var state = AppState(alert: .symbolsUnavailable)
        _ = AppReducer.reduce(&state, .feed(.connectionLost))
        #expect(state.alert == .symbolsUnavailable)
    }

    @Test func dismissClearsTheAlert() {
        var state = AppState(alert: .connectionLost)
        #expect(AppReducer.reduce(&state, .alertDismissed).isEmpty)
        #expect(state.alert == nil)
    }

    @Test func retryingASymbolsAlertRefetches() {
        var state = AppState(alert: .symbolsUnavailable)
        #expect(AppReducer.reduce(&state, .alertRetryTapped(.symbolsUnavailable)) == [.fetchSymbols])
        #expect(state.alert == nil)
        #expect(state.isLoadingSymbols)
    }

    @Test func retryingAConnectionAlertReconnects() {
        var state = AppState(alert: .connectionLost)
        #expect(AppReducer.reduce(&state, .alertRetryTapped(.connectionLost)) == [.reconnectFeed])
        #expect(state.alert == nil)
    }
}
