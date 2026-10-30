//
//  StockSymbolsProvider.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

// MARK: - StockSymbolsFetchUseCase
nonisolated
protocol StockSymbolsFetchUseCase: Sendable {
    /// `GET /symbols`: the symbols to track, each with its latest known price and when it was observed.
    func fetchStockSymbols() async throws -> [StockSymbolPrice]
}

// MARK: - StockSymbolFetchUseCase
nonisolated
protocol StockSymbolFetchUseCase: Sendable {
    /// `GET /symbols/{id}`: one symbol with its latest known price.
    /// - Throws: `StockSymbolsProviderError.notFound` when the backend has no such symbol.
    func fetchStockSymbol(id: String) async throws -> StockSymbolPrice
}

/// The stock-symbols backend API, as the app sees it. Each method mirrors an endpoint:
/// `GET /symbols` and `GET /symbols/{id}`. Implementations do their work off the main thread.
nonisolated
protocol StockSymbolsProvider: StockSymbolsFetchUseCase, StockSymbolFetchUseCase {
}

nonisolated enum StockSymbolsProviderError: Error, Equatable {
    /// `404`: no symbol with this id.
    case notFound(id: String)
}
