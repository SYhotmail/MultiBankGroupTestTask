//
//  StockMarketModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// The Model in MVVM: live symbols, quotes and feed state shared by every screen's view model.
/// Knows nothing about presentation (sorting, alerts, formatting).
///
/// Main-actor isolated because SwiftUI observes it; the feed and repository it drives are actors,
/// so their work runs off the main thread and results come back here with `await`.
@MainActor
@Observable
final class StockMarketModel {
    /// A problem the user should hear about.
    enum Issue: Equatable {
        case symbolsUnavailable
        case connectionLost
    }

    private(set) var symbols: [StockSymbol] = []
    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var isLoadingSymbols = false
    private(set) var issue: Issue?

    @ObservationIgnored private let repository: any SymbolsRepository
    @ObservationIgnored private let feed: any PriceFeed

    init(repository: any SymbolsRepository, feed: any PriceFeed) {
        self.repository = repository
        self.feed = feed
    }

    var isFeedRunning: Bool { connectionState != .disconnected }

    func quote(for symbol: StockSymbol) -> StockQuote {
        quotes[symbol.ticker] ?? StockQuote(price: symbol.referencePrice)
    }

    /// Fetches the symbol list. Quotes of symbols that remain are kept; a failure raises an issue.
    func loadSymbols() async {
        isLoadingSymbols = true
        defer { isLoadingSymbols = false }
        do {
            await replaceSymbols(with: try await repository.fetchSymbols())
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
        } catch {
            issue = .symbolsUnavailable
        }
    }

    /// Reconnects the running feed right away and reloads the symbol list.
    func refresh() async {
        await feed.reconnect()
        await loadSymbols()
    }

    func toggleFeed() async {
        if isFeedRunning {
            await feed.stop()
        } else {
            await feed.start()
        }
    }

    func reconnectFeed() async {
        await feed.reconnect()
    }

    func clearIssue() {
        issue = nil
    }

    /// The app moved to the background; sockets don't survive suspension, so drop it cleanly.
    func appDidEnterBackground() async {
        await feed.suspend()
    }

    /// The app is active again; reconnects if the feed was running before going to the background.
    func appDidBecomeActive() async {
        await feed.resume()
    }

    /// Applies feed events until the feed's stream ends. Run once for the model's lifetime.
    func observeFeed() async {
        for await event in feed.events {
            apply(event)
        }
    }

    func apply(_ event: PriceFeedEvent) {
        switch event {
        case .connectionChanged(let state):
            connectionState = state
        case .priceUpdates(let updates):
            for update in updates {
                // Ignore symbols we do not track.
                guard let quote = quotes[update.symbol] else { continue }
                quotes[update.symbol] = quote.updated(to: update.price)
            }
        case .connectionLost:
            // Don't replace an issue the user hasn't seen yet.
            issue = issue ?? .connectionLost
        }
    }

    private func replaceSymbols(with fetched: [StockSymbol]) async {
        // Remote data may repeat a ticker; keep the first so tickers stay unique identifiers.
        var seen = Set<String>()
        let unique = fetched.filter { seen.insert($0.ticker).inserted }
        quotes = Dictionary(uniqueKeysWithValues: unique.map { ($0.ticker, quote(for: $0)) })
        symbols = unique
        await feed.track(unique)
    }
}
