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
        case symbolUnavailable(ticker: String)
        case connectionLost
    }

    private(set) var symbols: [StockSymbol] = []
    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var isLoadingSymbols = false
    private(set) var issue: Issue?

    @ObservationIgnored private let repository: any StockSymbolsRepository
    @ObservationIgnored private let feed: any PriceFeed

    init(repository: any StockSymbolsRepository, feed: any PriceFeed) {
        self.repository = repository
        self.feed = feed
    }

    var isFeedRunning: Bool { connectionState != .disconnected }

    /// The tracked symbol with this ticker, or `nil` if the model doesn't track it.
    func symbol(ticker: String) -> StockSymbol? {
        symbols.first { $0.ticker == ticker }
    }

    /// The live quote, or `nil` for a symbol the model doesn't track (e.g. removed by a refresh).
    func quote(for symbol: StockSymbol) -> StockQuote? {
        quotes[symbol.ticker]
    }

    /// Fetches the symbol list. Quotes of symbols that remain are kept; a failure raises an issue.
    func loadSymbols() async {
        isLoadingSymbols = true
        defer { isLoadingSymbols = false }
        do {
            await replaceSymbols(with: try await repository.fetchStockSymbols())
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
        } catch {
            issue = .symbolsUnavailable
        }
    }

    /// Re-fetches one symbol (`GET /symbols/{id}`). Updates its details, and its quote when the
    /// backend's price is newer than the live one; a failure raises an issue.
    func refreshSymbol(ticker: String) async {
        do {
            let fetched = try await repository.fetchStockSymbol(id: ticker)
            // Trust boundary: accept only the symbol we asked for, and only while we still track it.
            guard fetched.symbol.ticker == ticker,
                  let index = symbols.firstIndex(where: { $0.ticker == ticker }) else { return }
            symbols[index] = fetched.symbol
            if let quote = quotes[ticker], fetched.timestamp > quote.updatedAt {
                quotes[ticker] = quote.updated(to: fetched.price, at: fetched.timestamp)
            }
        } catch StockSymbolsRepositoryError.notFound {
            // The backend deleted the symbol: stop tracking it, as a list reload without it would.
            await removeSymbol(ticker: ticker)
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
        } catch {
            // Don't replace an issue the user hasn't seen yet.
            issue = issue ?? .symbolUnavailable(ticker: ticker)
        }
    }

    private func removeSymbol(ticker: String) async {
        guard symbols.contains(where: { $0.ticker == ticker }) else { return }
        symbols.removeAll { $0.ticker == ticker }
        quotes[ticker] = nil
        // The feed keeps its own prices for symbols it already tracks, so passing the current quotes is enough.
        await feed.track(symbols.compactMap { symbol in
            quotes[symbol.ticker].map { StockSymbolPrice(symbol: symbol, price: $0.price, timestamp: $0.updatedAt) }
        })
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
                quotes[update.symbol] = quote.updated(to: update.price, at: update.timestamp)
            }
        case .connectionLost:
            // Don't replace an issue the user hasn't seen yet.
            issue = issue ?? .connectionLost
        }
    }

    private func replaceSymbols(with fetched: [StockSymbolPrice]) async {
        // Remote data may repeat a ticker; keep the first so tickers stay unique identifiers.
        var seen = Set<String>()
        let unique = fetched.filter { seen.insert($0.symbol.ticker).inserted }
        // Symbols that remain keep their live quote; new ones start from the fetched price.
        quotes = Dictionary(uniqueKeysWithValues: unique.map { symbolPrice in
            let ticker = symbolPrice.symbol.ticker
            return (ticker, quotes[ticker] ?? StockQuote(price: symbolPrice.price, updatedAt: symbolPrice.timestamp))
        })
        symbols = unique.map(\.symbol)
        await feed.track(unique)
    }
}
