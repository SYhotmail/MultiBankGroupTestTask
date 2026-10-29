//
//  StockSymbolDetailViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// Presentation logic for one symbol's detail screen. Reads live data from the shared model,
/// so the price keeps updating while the screen is open.
@Observable
final class StockSymbolDetailViewModel {
    let symbol: StockSymbol

    @ObservationIgnored private let market: StockMarketModel

    init(symbol: StockSymbol, market: StockMarketModel) {
        self.symbol = symbol
        self.market = market
    }

    var quote: StockQuote { market.quote(for: symbol) }

    var connectionState: ConnectionState { market.connectionState }

    func toggleFeed() {
        market.toggleFeed()
    }
}
