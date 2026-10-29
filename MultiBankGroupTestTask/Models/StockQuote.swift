//
//  StockQuote.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

nonisolated enum PriceDirection: Sendable {
    case up
    case down
    case unchanged
}

/// Current price of a symbol, its change since the previous update and when that update happened.
/// Explicitly `nonisolated`: plain data, usable from any actor regardless of the module's default isolation.
nonisolated struct StockQuote: Equatable, Sendable {
    let price: Decimal
    let change: Decimal
    /// When this price was observed: the reference price's timestamp until the first live update.
    let updatedAt: Date

    init(price: Decimal, change: Decimal = 0, updatedAt: Date) {
        self.price = price
        self.change = change
        self.updatedAt = updatedAt
    }

    var direction: PriceDirection {
        if change > 0 { return .up }
        if change < 0 { return .down }
        return .unchanged
    }

    func updated(to newPrice: Decimal, at timestamp: Date) -> StockQuote {
        StockQuote(price: newPrice, change: newPrice - price, updatedAt: timestamp)
    }
}

/// Wire format of a single price update sent to, and echoed back by, the WebSocket.
nonisolated struct PriceUpdate: Codable, Equatable, Sendable {
    let symbol: String
    let price: Decimal
    /// When the price was generated; encoded as ISO 8601 on the wire.
    let timestamp: Date
}

nonisolated enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
}
