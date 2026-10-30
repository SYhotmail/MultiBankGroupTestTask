//
//  StockSymbolsErrorTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 30/10/2026.
//

import Testing
@testable import MultiBankGroupTestTask

struct StockSymbolsErrorTests {
    @Test func alertTextForEachError() {
        #expect(StockSymbolsError.symbolsUnavailable.errorDescription == "Couldn't Load Symbols")
        #expect(StockSymbolsError.symbolsUnavailable.recoverySuggestion == "Check your connection and try again.")

        #expect(StockSymbolsError.symbolUnavailable(ticker: "AAPL").errorDescription == "Couldn't Refresh AAPL")
        #expect(StockSymbolsError.symbolUnavailable(ticker: "AAPL").recoverySuggestion == "Check your connection and try again.")

        #expect(StockSymbolsError.connectionLost.errorDescription == "Connection Problem")
        #expect(StockSymbolsError.connectionLost.recoverySuggestion == "Live prices are unavailable. The app will keep trying to reconnect.")
    }
}
