//
//  StockSymbolDetailViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation
import OSLog

/// One symbol's detail screen: its details (kept in the list, which owns which symbols exist), its live
/// quote from the shared `StockSymbolsPriceListener`, and refreshing it from the backend (`GET /symbols/{id}`).
@MainActor
@Observable
final class StockSymbolDetailViewModel: StockSymbolBaseViewModel {
    private let initialSymbol: StockSymbol
    private let list: StockSymbolsListViewModel

    init(
        symbol: StockSymbol,
        list: StockSymbolsListViewModel,
        provider: any StockSymbolsProvider,
        market: StockSymbolsPriceListener,
        feed: any PriceFeed,
        logger: Logger,
        onIssue: StockSymbolsIssueHandler? = nil
    ) {
        initialSymbol = symbol
        self.list = list
        super.init(provider: provider, market: market, feed: feed, logger: logger, onIssue: onIssue)
    }
    
    private var ticker: String { initialSymbol.ticker }
    
    /// The symbol's latest details (a refresh may update its name or description);
    /// falls back to the opened symbol once it's no longer listed.
    var symbol: StockSymbol { listSymbol() ?? initialSymbol }
    
    /// `nil` once the symbol is no longer priced, e.g. a refresh removed it while this screen was open.
    var quote: StockQuote? { market.quote(for: ticker) }
    
    /// Pull-to-refresh: reconnects the feed and re-fetches this symbol. Updates its details, and its quote
    /// when the backend's price is newer than the live one. A `404` deletes the symbol; other failures are reported.
    override func refresh() async {
        await super.refresh()
        do {
            let fetched = try await provider.fetchStockSymbol(id: ticker)
            // Trust boundary: accept only the symbol we asked for, and only while it's still listed.
            guard fetched.symbol.ticker == ticker, listSymbol() != nil else {
                logger.warning("Ignored refresh of \(self.ticker, privacy: .public): got \(fetched.symbol.ticker, privacy: .public) or it's no longer listed")
                return
            }
            list.replace(fetched.symbol)
            market.applyIfNewer(fetched)
            logger.info("Refreshed \(self.ticker, privacy: .public)")
        } catch StockSymbolsProviderError.notFound {
            // The backend deleted the symbol: drop it, as a list reload without it would.
            await list.remove(ticker: ticker)
        } catch is CancellationError {
            // The caller went away (e.g. pull-to-refresh was cancelled); nothing to report.
            logger.debug("Refresh of \(self.ticker, privacy: .public) cancelled")
        } catch {
            logger.error("Couldn't refresh \(self.ticker, privacy: .public): \(String(reflecting: error))")
            onIssue?(.symbolUnavailable(ticker: ticker), String(reflecting: error))
        }
    }
    
    func listSymbol() -> StockSymbol? {
        list.symbol(ticker: ticker)
    }
}
