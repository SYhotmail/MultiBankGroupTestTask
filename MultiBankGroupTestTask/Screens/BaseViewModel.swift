//
//  BaseViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// What every screen's view model shares: the live market model and the feed controls shown in each
/// screen's toolbar.
///
/// Not `@Observable` itself: it stores only constants, so there is nothing to track; reads of
/// `connectionState` are tracked through `StockMarketModel`. Subclasses add `@Observable` for their own state.
@MainActor
class BaseViewModel {
    let market: StockMarketModel
    let feed: any PriceFeed

    init(market: StockMarketModel, feed: any PriceFeed) {
        self.market = market
        self.feed = feed
    }

    var connectionState: ConnectionState { market.connectionState }

    var isFeedRunning: Bool { market.isFeedRunning }

    /// Start/Stop button.
    func toggleFeed() async {
        if isFeedRunning {
            await feed.stop()
        } else {
            await feed.start()
        }
    }

    /// Reconnects the running feed right away, skipping any backoff wait.
    func reconnectFeed() async {
        await feed.reconnect()
    }
}
