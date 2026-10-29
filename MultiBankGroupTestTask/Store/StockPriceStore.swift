//
//  StockPriceStore.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Observation

/// Single source of truth for prices and feed state, shared by every screen.
@Observable
final class StockPriceStore {
    enum SortOrder: CaseIterable, Hashable {
        case price
        case priceChange
    }

    /// A problem worth interrupting the user for.
    enum Alert: Equatable {
        case symbolsUnavailable
        case connectionLost
    }

    private(set) var symbols: [StockSymbol] = []
    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var isLoadingSymbols = false
    private(set) var alert: Alert?
    var sortOrder: SortOrder = .price

    @ObservationIgnored private let repository: any SymbolsRepository
    @ObservationIgnored private let feed: any PriceFeed

    init(repository: any SymbolsRepository, feed: any PriceFeed) {
        self.repository = repository
        self.feed = feed
    }

    var isFeedRunning: Bool { connectionState != .disconnected }

    /// Symbols ordered by `sortOrder`, highest first; ties fall back to ticker order.
    var sortedSymbols: [StockSymbol] {
        symbols.sorted { lhs, rhs in
            let lhsQuote = quote(for: lhs)
            let rhsQuote = quote(for: rhs)
            let (lhsValue, rhsValue) = switch sortOrder {
            case .price: (lhsQuote.price, rhsQuote.price)
            case .priceChange: (lhsQuote.change, rhsQuote.change)
            }
            return lhsValue == rhsValue ? lhs.ticker < rhs.ticker : lhsValue > rhsValue
        }
    }

    func quote(for symbol: StockSymbol) -> StockQuote {
        quotes[symbol.ticker] ?? StockQuote(price: symbol.referencePrice)
    }

    /// Fetches the symbol list. Quotes of symbols that remain are kept; a failure raises an alert.
    func loadSymbols() async {
        isLoadingSymbols = true
        defer { isLoadingSymbols = false }
        do {
            replaceSymbols(with: try await repository.fetchSymbols())
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
        } catch {
            alert = .symbolsUnavailable
        }
    }

    /// Pull-to-refresh: reconnects the running feed right away and reloads the symbol list.
    func refresh() async {
        feed.reconnect()
        await loadSymbols()
    }

    func dismissAlert() {
        alert = nil
    }

    func retry(_ alert: Alert) async {
        dismissAlert()
        switch alert {
        case .symbolsUnavailable: await loadSymbols()
        case .connectionLost: feed.reconnect()
        }
    }

    private func replaceSymbols(with fetched: [StockSymbol]) {
        // Remote data may repeat a ticker; keep the first so tickers stay unique identifiers.
        var seen = Set<String>()
        let unique = fetched.filter { seen.insert($0.ticker).inserted }
        quotes = Dictionary(uniqueKeysWithValues: unique.map { ($0.ticker, quotes[$0.ticker] ?? StockQuote(price: $0.referencePrice)) })
        symbols = unique
        feed.track(unique)
    }

    func toggleFeed() {
        if isFeedRunning {
            feed.stop()
        } else {
            feed.start()
        }
    }

    /// The app moved to the background; sockets don't survive suspension, so drop it cleanly.
    func appDidEnterBackground() {
        feed.suspend()
    }

    /// The app is active again; reconnects if the feed was running before going to the background.
    func appDidBecomeActive() {
        feed.resume()
    }

    /// Applies feed events until the feed's stream ends. Run once for the store's lifetime.
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
            // Don't replace an alert the user hasn't seen yet.
            alert = alert ?? .connectionLost
        }
    }
}
