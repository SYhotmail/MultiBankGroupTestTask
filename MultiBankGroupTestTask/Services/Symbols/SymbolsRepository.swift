//
//  SymbolsRepository.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// Source of the symbols the app tracks.
protocol SymbolsRepository {
    func fetchSymbols() async throws -> [StockSymbol]
}

/// Serves the built-in catalog. Replace with a network-backed repository once a symbols API exists.
struct BundledSymbolsRepository: SymbolsRepository {
    func fetchSymbols() async throws -> [StockSymbol] {
        StockSymbol.catalog
    }
}
