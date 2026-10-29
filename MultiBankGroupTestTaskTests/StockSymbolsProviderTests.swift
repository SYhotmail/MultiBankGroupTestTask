//
//  StockSymbolsProviderTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// The bundled provider behaves like the backend endpoints it stands in for.
struct StockSymbolsProviderTests {
    private let provider = BundledStockSymbolsRepository(latency: .zero)

    @Test func listReturnsTheCatalog() async throws {
        #expect(try await provider.fetchStockSymbols() == StockSymbolPrice.catalog)
    }

    @Test func fetchByIdReturnsThatSymbol() async throws {
        let symbolPrice = try await provider.fetchStockSymbol(id: "NVDA")
        #expect(symbolPrice.symbol.ticker == "NVDA")
        #expect(symbolPrice == StockSymbolPrice.catalog.first { $0.symbol.ticker == "NVDA" })
    }

    @Test func unknownIdIsNotFound() async {
        await #expect(throws: StockSymbolsProviderError.notFound(id: "ZZZZ")) {
            try await provider.fetchStockSymbol(id: "ZZZZ")
        }
    }
}
