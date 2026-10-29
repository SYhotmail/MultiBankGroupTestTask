//
//  StockSymbolsNavigationViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// Root of the screen hierarchy: owns the list view model, builds detail view models and turns
/// model issues into alerts shown above whichever screen is visible.
@MainActor
@Observable
final class StockSymbolsNavigationViewModel {
    let listViewModel: StockSymbolsListViewModel

    private let market: StockMarketModel

    init(market: StockMarketModel) {
        self.market = market
        listViewModel = StockSymbolsListViewModel(market: market)
    }

    var alert: StockMarketModel.Issue? { market.issue }

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
