//
//  SymbolsRepository.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// Source of the symbols the app tracks. Implementations do their work off the main thread.
protocol SymbolsRepository: Sendable {
    func fetchSymbols() async throws -> [StockSymbol]
}

/// Serves the built-in catalog. Replace with a network-backed repository once a symbols API exists;
/// as an actor it can then own a cache or in-flight request without extra locking.
actor BundledSymbolsRepository: SymbolsRepository {
    func fetchSymbols() async throws -> [StockSymbol] {
        StockSymbol.catalog
    }
}
