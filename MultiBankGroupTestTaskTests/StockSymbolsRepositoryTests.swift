//
//  StockSymbolsRepositoryTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// The bundled repository behaves like the backend endpoints it stands in for.
struct StockSymbolsRepositoryTests {
    private let repository = BundledStockSymbolsRepository(latency: .zero)

    @Test func listReturnsTheCatalog() async throws {
        #expect(try await repository.fetchStockSymbols() == StockSymbolPrice.catalog)
    }

    @Test func fetchByIdReturnsThatSymbol() async throws {
        let symbolPrice = try await repository.fetchStockSymbol(id: "NVDA")
        #expect(symbolPrice.symbol.ticker == "NVDA")
        #expect(symbolPrice == StockSymbolPrice.catalog.first { $0.symbol.ticker == "NVDA" })
    }

    @Test func unknownIdIsNotFound() async {
        await #expect(throws: StockSymbolsRepositoryError.notFound(id: "ZZZZ")) {
            try await repository.fetchStockSymbol(id: "ZZZZ")
        }
    }
}
