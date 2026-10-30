//
//  StockSymbolDetailViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation
import OSLog

/// One symbol's detail screen: its details (the list owns which symbols exist, and is reached only through
/// the closures given at init), its live quote from the shared `StockSymbolsPriceListener`, and refreshing
/// it from the backend (`GET /symbols/{id}`).
@Observable
final class StockSymbolDetailViewModel: StockSymbolBaseViewModel {
    private let initialSymbol: StockSymbol
    /// The listed symbol with a ticker, or `nil` once it's no longer listed. Read while a view renders,
    /// so the view follows the list's changes.
    private let listedSymbol: @MainActor (String) -> StockSymbol?
    private let onSymbolUpdated: (StockSymbol) -> Void
    private let onSymbolDeleted: (String) async -> Void

    init(
        symbol: StockSymbol,
        provider: any StockSymbolsProvider,
        market: StockSymbolsPriceListener,
        feed: any PriceFeed,
        logger: Logger,
        listedSymbol: @escaping @MainActor (String) -> StockSymbol?,
        onSymbolUpdated: @escaping (StockSymbol) -> Void,
        onSymbolDeleted: @escaping (String) async -> Void,
        onIssue: StockSymbolsIssueHandler? = nil
    ) {
        initialSymbol = symbol
        self.listedSymbol = listedSymbol
        self.onSymbolUpdated = onSymbolUpdated
        self.onSymbolDeleted = onSymbolDeleted
        super.init(provider: provider, market: market, feed: feed, logger: logger, onIssue: onIssue)
    }
    
    private var ticker: String { initialSymbol.ticker }
    
    /// The symbol's latest details (a refresh may update its name or description);
    /// falls back to the opened symbol once it's no longer listed.
    var symbol: StockSymbol { listSymbol() ?? initialSymbol }
    
    /// `nil` once the symbol is no longer priced, e.g. a refresh removed it while this screen was open.
    var quote: StockQuote? { market.quote(for: ticker) }
    
    private func fetchStockSymbol(id: String) async throws -> StockSymbolPrice {
        try await provider.fetchStockSymbol(id: id)
    }
    
    /// Pull-to-refresh: reconnects the feed and re-fetches this symbol. Updates its details, and its quote
    /// when the backend's price is newer than the live one. A `404` deletes the symbol; other failures are reported.
    override func refresh() async {
        await super.refresh()
        do {
            let fetched = try await fetchStockSymbol(id: ticker)
            // Trust boundary: accept only the symbol we asked for, and only while it's still listed.
            guard fetched.symbol.ticker == ticker, listSymbol() != nil else {
                logger.warning("Ignored refresh of \(self.ticker): got \(fetched.symbol.ticker) or it's no longer listed")
                return
            }
            onSymbolUpdated(fetched.symbol)
            market.applyIfNewer(fetched)
            logger.info("Refreshed \(self.ticker)")
        } catch StockSymbolsProviderError.notFound {
            // The backend deleted the symbol: drop it, as a list reload without it would.
            await onSymbolDeleted(ticker)
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
            logger.debug("Refresh of \(self.ticker) cancelled")
        } catch {
            let errorText = String(reflecting: error)
            logger.error("Couldn't refresh \(self.ticker, privacy: .public): \(errorText)")
            onIssue?(.symbolUnavailable(ticker: ticker), errorText)
        }
    }
    
    func listSymbol() -> StockSymbol? {
        listedSymbol(ticker)
    }
}
