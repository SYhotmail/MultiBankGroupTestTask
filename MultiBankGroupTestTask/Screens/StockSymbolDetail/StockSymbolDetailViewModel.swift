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
@MainActor
@Observable
final class StockSymbolDetailViewModel {
    @ObservationIgnored private let initialSymbol: StockSymbol
    @ObservationIgnored private let market: StockMarketModel

    init(symbol: StockSymbol, market: StockMarketModel) {
        initialSymbol = symbol
        self.market = market
    }

    /// The symbol's latest details from the model (a refresh may update its name or description);
    /// falls back to the opened symbol once the model stops tracking it.
    var symbol: StockSymbol { market.symbol(ticker: initialSymbol.ticker) ?? initialSymbol }

    /// `nil` once the symbol is no longer tracked, e.g. a refresh removed it while this screen was open.
    var quote: StockQuote? { market.quote(for: initialSymbol) }

    /// The symbol was deleted: the backend returned 404 for it, or a list reload dropped it.
    /// The screen closes when this becomes true.
    var isDeleted: Bool { market.symbol(ticker: initialSymbol.ticker) == nil }

    var connectionState: ConnectionState { market.connectionState }

    /// Pull-to-refresh: re-fetches this symbol from the backend.
    func refresh() async {
        await market.refreshSymbol(ticker: initialSymbol.ticker)
    }

    func toggleFeed() async {
        await market.toggleFeed()
    }
}
