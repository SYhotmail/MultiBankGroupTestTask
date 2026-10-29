//
//  StockSymbolsListView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsListView: View {
    @Environment(StockPriceStore.self) private var store

    var body: some View {
        @Bindable var store = store

        // Rows live in a child view so price ticks don't rebuild the toolbar (and dismiss the sort menu).
        StockSymbolsList(store: store)
            .navigationTitle("Stocks")
            .toolbar {
                FeedToolbar(store: store)
                ToolbarItem(placement: .primaryAction) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort by", selection: $store.sortOrder) {
                            Label("Price", systemImage: "dollarsign").tag(StockPriceStore.SortOrder.price)
                            Label("Price Change", systemImage: "plusminus").tag(StockPriceStore.SortOrder.priceChange)
                        }
                    }
                }
            }
    }
}

private struct StockSymbolsList: View {
    let store: StockPriceStore

    var body: some View {
        List(store.sortedSymbols) { symbol in
            NavigationLink(value: symbol) {
                StockSymbolRow(symbol: symbol, quote: store.quote(for: symbol))
            }
        }
        .listStyle(.plain)
        .animation(.default, value: store.sortedSymbols)
        .refreshable { await store.refresh() }
        .overlay {
            if store.symbols.isEmpty && store.isLoadingSymbols {
                ProgressView()
            }
        }
        .task {
            if store.symbols.isEmpty {
                await store.loadSymbols()
            }
        }
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
        StockSymbolsListView()
    }
    .environment(StockPriceStore.preview)
}
