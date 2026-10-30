//
//  StockSymbolBaseViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import OSLog

/// What every screen's view model shares: the backend, the live price listener, the feed controls shown
/// in each screen's toolbar, and where failures are reported.
///
/// Not `@Observable` itself: it holds dependencies and a callback, nothing a view renders; reads of
/// `connectionState` are tracked through `StockSymbolsPriceListener`. Subclasses add `@Observable` for their own state.
class StockSymbolBaseViewModel {
    let provider: any StockSymbolsProvider
    let priceListener: StockSymbolsPriceListener
    let feed: any PriceFeedProvider
    let logger: Logger
    /// Where a failed load or refresh is reported.
    var onIssue: StockSymbolsIssueHandler?

    init(
        provider: any StockSymbolsProvider,
        priceListener: StockSymbolsPriceListener,
        feed: any PriceFeedProvider,
        logger: Logger,
        onIssue: StockSymbolsIssueHandler? = nil
    ) {
        self.provider = provider
        self.priceListener = priceListener
        self.feed = feed
        self.logger = logger
        self.onIssue = onIssue
    }

    var connectionState: ConnectionState { priceListener.connectionState }

    var isFeedRunning: Bool { priceListener.isFeedRunning }

    /// Start/Stop button.
    func toggleFeed() async {
        if isFeedRunning {
            logger.info("Stopping the price feed")
            await feed.stop()
        } else {
            logger.info("Starting the price feed")
            await feed.start()
        }
    }

    /// Reconnects the running feed right away, skipping any backoff wait.
    func reconnectFeed() async {
        logger.info("Reconnecting the price feed")
        await feed.reconnect()
    }

    /// Pull-to-refresh: reconnects the feed. Subclasses refresh their own data too, after `super.refresh()`.
    func refresh() async {
        await reconnectFeed()
    }
}
