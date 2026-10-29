//
//  StockSymbolsNavigationViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation
import OSLog

/// Root of the screen hierarchy and their coordinator. Creates the shared `StockSymbolsMarketModel` (the live
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
    private let market: StockSymbolsMarketModel
    private var storedSelection: String?
    let feed: any PriceFeed
    private let logger: Logger

    /// - Parameter logger: Shared with the screens' view models; pass `.empty` in tests.
    init(provider: any StockSymbolsProvider, feed: any PriceFeed, logger: Logger) {
        let market = StockSymbolsMarketModel(feed: feed)
        self.provider = provider
        self.market = market
        self.feed = feed
        self.logger = logger
        listViewModel = StockSymbolsListViewModel(provider: provider, market: market, feed: feed, logger: logger)

        // Weak: this view model owns the market and the list, so strong captures would be retain cycles.
        listViewModel.onIssue = { [weak self] issue, reason in self?.report(issue, debugDescription: reason) }
        market.onConnectionLost = { [weak self] reason in
            self?.logger.error("Connection lost: \(reason)")
            self?.report(.connectionLost, debugDescription: reason)
        }
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
                                   feed: feed,
                                   logger: logger) { [weak self] issue, reason in
            self?.report(issue, debugDescription: reason)
        }
    }

    /// Turns feed events into live quotes until the feed's stream ends. Run once for the app's lifetime.
    func observeFeed() async {
        await market.observeFeed()
    }

    func appDidEnterBackground() {
        logger.info("Entered background: suspending the price feed")
        Task {
            await feed.suspend()
        }
    }

    func appDidBecomeActive() {
        logger.info("Became active: resuming the price feed")
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
        guard alert == nil else {
            logger.notice("Not showing \(String(describing: issue), privacy: .public): another alert is showing")
            return
        }
        logger.notice("Showing alert for \(String(describing: issue), privacy: .public)")
        alert = issue
        alertDebugDescription = debugDescription
    }
}
