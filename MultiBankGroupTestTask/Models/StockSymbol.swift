//
//  StockSymbol.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

/// Static reference data for a tradable symbol. Live prices live in `StockQuote`.
/// Explicitly `nonisolated`: plain data, usable from any actor regardless of the module's default isolation.
nonisolated struct StockSymbol: Hashable, Identifiable, Sendable {
    let ticker: String
    let name: String
    let summary: String
    /// Price the feed starts its random walk from.
    let referencePrice: Decimal

    var id: String { ticker }
}
