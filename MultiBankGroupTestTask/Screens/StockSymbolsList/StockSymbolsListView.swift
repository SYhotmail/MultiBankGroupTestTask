//
//  StockSymbolsListView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsListView: View {
    @Bindable var viewModel: StockSymbolsListViewModel

    var body: some View {
        // Rows live in a child view so price ticks don't rebuild the toolbar (and dismiss the sort menu).
        StockSymbolsList(viewModel: viewModel)
            .navigationTitle("Stocks")
            .toolbar {
                FeedToolbar(connectionState: viewModel.connectionState, toggleFeed: viewModel.toggleFeed)
                ToolbarItem(placement: .primaryAction) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort by", selection: $viewModel.sortOrder) {
                            Label("Price", systemImage: "dollarsign").tag(StockSymbolsListViewModel.SortOrder.price)
                            Label("Price Change", systemImage: "plusminus").tag(StockSymbolsListViewModel.SortOrder.priceChange)
                        }
                    }
                }
            }
    }
}

private struct StockSymbolsList: View {
    let viewModel: StockSymbolsListViewModel

    var body: some View {
        let rows = viewModel.rows
        List(rows) { row in
            NavigationLink(value: row.symbol) {
                StockSymbolRow(symbol: row.symbol, quote: row.quote)
            }
        }
        .listStyle(.plain)
        .animation(.default, value: rows.map(\.id))
        .refreshable { await viewModel.refresh() }
        .overlay {
            if viewModel.showsLoadingIndicator {
                ProgressView()
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }
}

struct StockSymbolRow: View {
    let symbol: StockSymbol
    let quote: StockQuote

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(symbol.ticker)
                    .font(.headline)
                Text(symbol.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing) {
                PriceText(price: quote.price)
                    .font(.headline)
                PriceChangeIndicator(quote: quote)
                    .font(.subheadline)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StockSymbolsListView(viewModel: StockSymbolsListViewModel(market: .preview))
    }
}
