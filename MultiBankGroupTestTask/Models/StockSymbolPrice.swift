//
//  StockSymbolPrice.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// A symbol's price at a point in time, e.g. the closing price a symbol list is published with.
/// The live feed starts its random walk from it, and it is the quote shown until the first update.
/// Explicitly `nonisolated`: plain data, usable from any actor regardless of the module's default isolation.
nonisolated struct StockSymbolPrice: Hashable, Identifiable, Sendable {
    let symbol: StockSymbol
    let price: Decimal
    /// When `price` was observed.
    let timestamp: Date

    var id: String { symbol.ticker }
}
