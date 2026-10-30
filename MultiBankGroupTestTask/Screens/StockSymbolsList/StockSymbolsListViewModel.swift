//
//  StockSymbolsListViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation
import OSLog

/// The symbols list: owns which symbols exist (loaded from the provider), sorting and the feed
/// controls shown above the list. Live prices come from the shared `StockSymbolsPriceListener`.
@Observable
final class StockSymbolsListViewModel: StockSymbolBaseViewModel {
    enum SortOrder: CaseIterable, Hashable {
        case price
        case priceChange
    }
    
    struct Row: Identifiable, Equatable {
        let symbol: StockSymbol
        let quote: StockQuote
        
        var id: String { symbol.ticker }
    }
    
    var sortOrder: SortOrder = .price {
        didSet { updateRows() }
    }
    
    private(set) var symbols: [StockSymbol] = [] {
        didSet { updateRows() }
    }
    private(set) var isLoading = false

    /// Rows ordered by `sortOrder`, highest first; ties fall back to ticker order.
    ///
    /// Stored, not computed: rebuilt only when the symbols, their quotes or the sort order change, so a
    /// redraw for anything else (e.g. the connection status) reads it as is. A price update still rebuilds
    /// it, since a new price can reorder the rows.
    private(set) var rows: [Row] = []

    @ObservationIgnored
    private(set) var rowsId: [String] = []
    
    override init(
        provider: any StockSymbolsProvider,
        priceListener: StockSymbolsPriceListener,
        feed: any PriceFeedProvider,
        logger: Logger,
        onIssue: StockSymbolsIssueHandler? = nil
    ) {
        super.init(provider: provider, priceListener: priceListener, feed: feed, logger: logger, onIssue: onIssue)
        // Weak: the navigation view model owns both the price listener and this list.
        priceListener.onQuotesChanged = { [weak self] in self?.updateRows() }
    }

    /// Spinner only while the very first load is in flight; a refresh keeps the current rows.
    var showsLoadingIndicator: Bool { symbols.isEmpty && isLoading }

    /// The listed symbol with this ticker, or `nil` if it isn't (or is no longer) listed.
    func symbol(ticker: String) -> StockSymbol? {
        symbols.first { $0.ticker == ticker }
    }

    func loadIfNeeded() async {
        guard symbols.isEmpty else { return }
        await load()
    }

    /// Pull-to-refresh: reconnects the running feed right away and reloads the list.
    override func refresh() async {
        await super.refresh()
        await load()
    }
    
    @concurrent
    private func fetchUniqueStockSymbols() async throws -> [StockSymbolPrice] {
        let fetched = try await provider.fetchStockSymbols()
        // Remote data may repeat a ticker; keep the first so tickers stay unique identifiers.
        var seen = Set<String>()
        let unique = fetched.filter { seen.insert($0.symbol.ticker).inserted }
        return unique
    }

    /// Fetches the list (`GET /symbols`). Symbols that remain keep their live quotes; a failure is reported.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let unique = try await fetchUniqueStockSymbols()
            await priceListener.track(unique)
            symbols = unique.map(\.symbol)
            logger.info("Loaded \(unique.count) symbols")
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
            logger.debug("Symbols load cancelled")
        } catch {
            let errorReflection = String(reflecting: error)
            logger.error("Couldn't load symbols: \(errorReflection)")
            onIssue?(.symbolsUnavailable, errorReflection)
        }
    }

    private func updateRows() {
        let quotes = priceListener.quotes
        let rows = symbols
            .compactMap { symbol in quotes[symbol.ticker].map { Row(symbol: symbol, quote: $0) } }
            .sorted { lhs, rhs in
                let (lhsValue, rhsValue) = switch sortOrder {
                case .price: (lhs.quote.price, rhs.quote.price)
                case .priceChange: (lhs.quote.change, rhs.quote.change)
                }
                return lhsValue == rhsValue ? lhs.id < rhs.id : lhsValue > rhsValue
            }
        self.rows = rows
        self.rowsId = rows.map(\.id)
    }

    /// Takes newer details for a listed symbol (e.g. from a detail refresh).
    func replace(_ symbol: StockSymbol) {
        guard let index = symbols.firstIndex(where: { $0.ticker == symbol.ticker }) else { return }
        symbols[index] = symbol
    }

    /// Drops a symbol the backend deleted, and stops pricing it.
    func remove(ticker: String) async {
        guard symbols.contains(where: { $0.ticker == ticker }) else { return }
        symbols.removeAll { $0.ticker == ticker }
        logger.notice("Removed \(ticker, privacy: .public), deleted by the backend")
        await priceListener.untrack(ticker: ticker)
    }
}
