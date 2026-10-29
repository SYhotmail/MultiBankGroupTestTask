//
//  StockSymbolsNavigationViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// Root of the screen hierarchy. Owns the shared `StockMarketModel` (nothing outside this view model
/// touches it), the list view model and the selection that drives the detail column, and turns model
/// issues into alerts shown above whichever column is visible.
@MainActor
@Observable
final class StockSymbolsNavigationViewModel {
    let listViewModel: StockSymbolsListViewModel

    private let market: StockMarketModel
    private var storedSelection: String?

    init(market: StockMarketModel) {
        self.market = market
        listViewModel = StockSymbolsListViewModel(market: market)
    }

    /// Ticker of the symbol shown in the detail column. Reads as `nil` once that symbol is deleted
    /// (a `404`, or a list reload without it), which closes the detail.
    var selectedTicker: String? {
        get { storedSelection.flatMap { market.symbol(ticker: $0)?.ticker } }
        set { storedSelection = newValue }
    }

    var selectedSymbol: StockSymbol? { selectedTicker.flatMap { market.symbol(ticker: $0) } }

    /// Turns feed events into model updates until the feed's stream ends. Run once for the app's lifetime.
    func observeFeed() async {
        await market.observeFeed()
    }

    func appDidEnterBackground() async {
        await market.appDidEnterBackground()
    }

    func appDidBecomeActive() async {
        await market.appDidBecomeActive()
    }

    var alert: StockMarketModel.Issue? { market.issue }

    /// The error behind `alert`, for Debug builds.
    var alertDebugDescription: String? { market.issueDebugDescription }

    func detailViewModel(for symbol: StockSymbol) -> StockSymbolDetailViewModel {
        StockSymbolDetailViewModel(symbol: symbol, market: market)
    }

    func dismissAlert() {
        market.clearIssue()
    }

    func retry(_ issue: StockMarketModel.Issue) async {
        market.clearIssue()
        switch issue {
        case .symbolsUnavailable: await market.loadSymbols()
        case .symbolUnavailable(let ticker): await market.refreshSymbol(ticker: ticker)
        case .connectionLost: await market.reconnectFeed()
        }
    }
}
