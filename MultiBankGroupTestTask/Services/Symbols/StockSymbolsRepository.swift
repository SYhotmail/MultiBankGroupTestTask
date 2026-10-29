//
//  StockSymbolsRepository.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// The stock-symbols backend API, as the app sees it. Each method mirrors an endpoint:
/// `GET /symbols` and `GET /symbols/{id}`. Implementations do their work off the main thread.
nonisolated
protocol StockSymbolsRepository: Sendable {
    /// `GET /symbols`: the symbols to track, each with its latest known price and when it was observed.
    func fetchStockSymbols() async throws -> [StockSymbolPrice]

    /// `GET /symbols/{id}`: one symbol with its latest known price.
    /// - Throws: `StockSymbolsRepositoryError.notFound` when the backend has no such symbol.
    func fetchStockSymbol(id: String) async throws -> StockSymbolPrice
}

nonisolated enum StockSymbolsRepositoryError: Error, Equatable {
    /// `404`: no symbol with this id.
    case notFound(id: String)
}

/// Serves the built-in catalog the way a backend would: asynchronously, after some latency, with
/// `notFound` for unknown ids. Swap for a network-backed implementation once the API exists.
///
/// A struct, not an actor: it has no mutable state to protect. Its methods are `@concurrent`, so
/// they run on the global concurrent executor — off the main thread — even when called from the
/// main-actor model. If it gains state (a cache, in-flight request de-duplication), make it an actor.
nonisolated struct BundledStockSymbolsRepository: StockSymbolsRepository {
    private let latency: Duration

    /// - Parameter latency: Simulated round-trip time, so loading states behave as against a server.
    init(latency: Duration = .milliseconds(300)) {
        self.latency = latency
    }

    @concurrent
    func fetchStockSymbols() async throws -> [StockSymbolPrice] {
        try await Task.sleep(for: latency)
        return StockSymbolPrice.catalog
    }

    @concurrent
    func fetchStockSymbol(id: String) async throws -> StockSymbolPrice {
        try await Task.sleep(for: latency)
        guard let symbolPrice = StockSymbolPrice.catalog.first(where: { $0.symbol.ticker == id }) else {
            throw StockSymbolsRepositoryError.notFound(id: id)
        }
        return symbolPrice
    }
}
