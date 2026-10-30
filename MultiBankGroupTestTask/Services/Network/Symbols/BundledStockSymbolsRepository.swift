//
//  BundledStockSymbolsRepository.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// Serves the built-in catalog the way a backend would: asynchronously, after some latency, with
/// `notFound` for unknown ids. Swap for a network-backed implementation once the API exists.
///
/// A struct, not an actor: it has no mutable state to protect. Its methods are `@concurrent`, so
/// they run on the global concurrent executor — off the main thread — even when called from the
/// main-actor model. If it gains state (a cache, in-flight request de-duplication), make it an actor.
nonisolated struct BundledStockSymbolsRepository: StockSymbolsProvider {
    private let latency: Duration?

    /// - Parameter latency: Simulated round-trip time, so loading states behave as against a server.
    init(latency: Duration? = .milliseconds(300)) {
        self.latency = latency
    }
    
    private func delayOnNeed() async throws {
        guard let latency else {
            return
        }
        try await Task.sleep(for: latency)
    }

    @concurrent
    func fetchStockSymbols() async throws -> [StockSymbolPrice] {
        try await delayOnNeed()
        return StockSymbolPrice.catalog
    }

    @concurrent
    func fetchStockSymbol(id: String) async throws -> StockSymbolPrice {
        try await delayOnNeed()
        guard let symbolPrice = StockSymbolPrice.catalog.first(where: { $0.symbol.ticker == id }) else {
            throw StockSymbolsProviderError.notFound(id: id)
        }
        return symbolPrice
    }
}
