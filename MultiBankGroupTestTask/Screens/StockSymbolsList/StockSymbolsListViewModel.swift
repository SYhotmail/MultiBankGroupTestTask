//
//  StockSymbolsListViewModel.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// Presentation logic for the symbols list: sorting, rows and feed controls.
@MainActor
@Observable
final class StockSymbolsListViewModel {
    enum SortOrder: CaseIterable, Hashable {
        case price
        case priceChange
    }

    struct Row: Identifiable, Equatable {
        let symbol: StockSymbol
        let quote: StockQuote

        var id: String { symbol.ticker }
    }

    /// Screen-only state: the model doesn't care how the list is ordered.
    var sortOrder: SortOrder = .price

    @ObservationIgnored private let market: StockMarketModel

    init(market: StockMarketModel) {
        self.market = market
    }

    /// Rows ordered by `sortOrder`, highest first; ties fall back to ticker order.
    var rows: [Row] {
        market.symbols
            .map { Row(symbol: $0, quote: market.quote(for: $0)) }
            .sorted { lhs, rhs in
                let (lhsValue, rhsValue) = switch sortOrder {
                case .price: (lhs.quote.price, rhs.quote.price)
                case .priceChange: (lhs.quote.change, rhs.quote.change)
                }
                return lhsValue == rhsValue ? lhs.id < rhs.id : lhsValue > rhsValue
            }
    }

    var connectionState: ConnectionState { market.connectionState }

    /// Spinner only while the very first load is in flight; a refresh keeps the current rows.
    var showsLoadingIndicator: Bool { market.symbols.isEmpty && market.isLoadingSymbols }

    func toggleFeed() async {
        await market.toggleFeed()
    }

    /// Pull-to-refresh.
    func refresh() async {
        await market.refresh()
    }

    func loadIfNeeded() async {
        guard market.symbols.isEmpty else { return }
        await market.loadSymbols()
    }
}
