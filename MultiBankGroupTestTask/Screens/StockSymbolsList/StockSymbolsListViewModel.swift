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
/// controls shown above the list. Live prices come from the shared `StockSymbolsMarketModel`.
@MainActor
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
    
    /// Everything `rows` depends on.
    private struct RowsInput: Equatable {
        let symbols: [StockSymbol]
        let quotes: [String: StockQuote]
        let sortOrder: SortOrder
    }

    var sortOrder: SortOrder = .price
    private(set) var symbols: [StockSymbol] = []
    private(set) var isLoading = false

    /// The last `rows` result and what it was built from. Ignored by observation: it's a cache, written
    /// while a view reads `rows`, and its inputs are observed anyway.
    @ObservationIgnored private var rowsCache: (input: RowsInput, rows: [Row])?

    /// Rows ordered by `sortOrder`, highest first; ties fall back to ticker order.
    ///
    /// Rebuilt only when the symbols, their quotes or the sort order change, not on every read (e.g. when
    /// the view redraws for the connection status). A price update still rebuilds them: it can reorder rows.
    /// Checking for changes is cheap: unchanged arrays and dictionaries share storage, so `==` returns early.
    var rows: [Row] {
        let input = RowsInput(symbols: symbols, quotes: market.quotes, sortOrder: sortOrder)
        if let rowsCache, rowsCache.input == input {
            return rowsCache.rows
        }
        let rows = input.symbols
            .compactMap { symbol in input.quotes[symbol.ticker].map { Row(symbol: symbol, quote: $0) } }
            .sorted { lhs, rhs in
                let (lhsValue, rhsValue) = switch input.sortOrder {
                case .price: (lhs.quote.price, rhs.quote.price)
                case .priceChange: (lhs.quote.change, rhs.quote.change)
                }
                return lhsValue == rhsValue ? lhs.id < rhs.id : lhsValue > rhsValue
            }
        rowsCache = (input, rows)
        return rows
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

    /// Fetches the list (`GET /symbols`). Symbols that remain keep their live quotes; a failure is reported.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await provider.fetchStockSymbols()
            // Remote data may repeat a ticker; keep the first so tickers stay unique identifiers.
            var seen = Set<String>()
            let unique = fetched.filter { seen.insert($0.symbol.ticker).inserted }
            await market.track(unique)
            symbols = unique.map(\.symbol)
            logger.info("Loaded \(unique.count) symbols")
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
            logger.debug("Symbols load cancelled")
        } catch {
            logger.error("Couldn't load symbols: \(String(reflecting: error))")
            onIssue?(.symbolsUnavailable, String(reflecting: error))
        }
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
        await market.untrack(ticker: ticker)
    }
}
