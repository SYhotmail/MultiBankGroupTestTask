//
//  StockQuote.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

enum PriceDirection: Sendable {
    case up
    case down
    case unchanged
}

/// Current price of a symbol and its change since the previous update.
struct StockQuote: Equatable, Sendable {
    let price: Decimal
    let change: Decimal

    init(price: Decimal, change: Decimal = 0) {
        self.price = price
        self.change = change
    }

    var direction: PriceDirection {
        if change > 0 { return .up }
        if change < 0 { return .down }
        return .unchanged
    }

    func updated(to newPrice: Decimal) -> StockQuote {
        StockQuote(price: newPrice, change: newPrice - price)
    }
}

/// Wire format of a single price update sent to, and echoed back by, the WebSocket.
struct PriceUpdate: Codable, Equatable, Sendable {
    let symbol: String
    let price: Decimal
}

enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
}
