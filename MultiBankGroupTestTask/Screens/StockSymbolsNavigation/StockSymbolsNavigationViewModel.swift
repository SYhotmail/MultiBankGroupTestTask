//
//  StockSymbolsNavigationViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// Root of the screen hierarchy and their coordinator. Creates the shared `StockMarketModel` (the live
/// connection) and the list view model from the services it's given, builds detail view models, owns the
/// selection that drives the detail column, and shows the one alert that any of them reports.
@MainActor
@Observable
final class StockSymbolsNavigationViewModel {
    let listViewModel: StockSymbolsListViewModel

    private(set) var alert: StockSymbolsIssue?
    /// The error behind `alert`, for Debug builds.
    private(set) var alertDebugDescription: String?

    private let provider: any StockSymbolsProvider
    private let market: StockMarketModel
    private var storedSelection: String?
    let feed: any PriceFeed
    
    init(provider: any StockSymbolsProvider, feed: any PriceFeed) {
        let market = StockMarketModel(feed: feed)
        self.provider = provider
        self.market = market
        self.feed = feed
        listViewModel = StockSymbolsListViewModel(provider: provider, market: market, feed: feed)

        // Weak: this view model owns the market and the list, so strong captures would be retain cycles.
        listViewModel.onIssue = { [weak self] issue, reason in self?.report(issue, debugDescription: reason) }
        market.onConnectionLost = { [weak self] reason in self?.report(.connectionLost, debugDescription: reason) }
    }

    /// Ticker of the symbol shown in the detail column. Reads as `nil` once that symbol is deleted
    /// (a `404`, or a list reload without it), which closes the detail.
    var selectedTicker: String? {
        get { storedSelection.flatMap { listViewModel.symbol(ticker: $0)?.ticker } }
        set { storedSelection = newValue }
    }

    var selectedSymbol: StockSymbol? { selectedTicker.flatMap { listViewModel.symbol(ticker: $0) } }

    func detailViewModel(for symbol: StockSymbol) -> StockSymbolDetailViewModel {
        StockSymbolDetailViewModel(symbol: symbol,
                                   list: listViewModel,
                                   provider: provider,
                                   market: market,
                                   feed: feed) { [weak self] issue, reason in
            self?.report(issue, debugDescription: reason)
        }
    }

    /// Turns feed events into live quotes until the feed's stream ends. Run once for the app's lifetime.
    func observeFeed() async {
        await market.observeFeed()
    }

    func appDidEnterBackground() {
        Task {
            await feed.suspend()
        }
    }
    

    func appDidBecomeActive() {
        Task {
            await feed.resume()
        }
    }

    func dismissAlert() {
        alert = nil
        alertDebugDescription = nil
    }

    func retry(_ issue: StockSymbolsIssue) async {
        dismissAlert()
        switch issue {
        case .symbolsUnavailable:
            await listViewModel.load()
        case .symbolUnavailable(let ticker):
            guard let symbol = listViewModel.symbol(ticker: ticker) else { return }
            await detailViewModel(for: symbol).refresh()
        case .connectionLost:
            await feed.reconnect()
        }
    }

    /// Shows `issue` unless an alert is already showing: don't replace one the user hasn't seen yet.
    private func report(_ issue: StockSymbolsIssue, debugDescription: String) {
        guard alert == nil else { return }
        alert = issue
        alertDebugDescription = debugDescription
    }
}
