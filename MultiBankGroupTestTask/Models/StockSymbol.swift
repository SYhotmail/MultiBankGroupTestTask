//
//  StockSymbol.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

/// Identity of a tradable symbol: what it is, not what it costs. Prices live in
/// `StockSymbolPrice` (a point-in-time price) and `StockQuote` (the live quote).
/// Explicitly `nonisolated`: plain data, usable from any actor regardless of the module's default isolation.
nonisolated struct StockSymbol: Hashable, Identifiable, Sendable {
    let ticker: String
    let name: String
    let summary: String

    var id: String { ticker }
}
