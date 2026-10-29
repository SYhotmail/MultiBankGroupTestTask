//
//  StockSymbolsListView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        // Rows live in a child view so price ticks don't rebuild the toolbar (and dismiss the sort menu).
        StockSymbolsList(store: store)
            .navigationTitle("Stocks")
            .toolbar {
                FeedToolbar(store: store)
                ToolbarItem(placement: .primaryAction) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort by", selection: Binding(get: { store.sortOrder }, set: { store.send(.sortOrderChanged($0)) })) {
                            Label("Price", systemImage: "dollarsign").tag(AppState.SortOrder.price)
                            Label("Price Change", systemImage: "plusminus").tag(AppState.SortOrder.priceChange)
                        }
                    }
                }
            }
    }
}

private struct StockSymbolsList: View {
    let store: AppStore

    var body: some View {
        let state = store.state
        List(state.sortedSymbols) { symbol in
            NavigationLink(value: symbol) {
                StockSymbolRow(symbol: symbol, quote: state.quote(for: symbol))
            }
        }
        .listStyle(.plain)
        .animation(.default, value: state.sortedSymbols)
        .refreshable { await store.send(.refreshRequested).value }
        .overlay {
            if store.symbols.isEmpty && store.isLoadingSymbols {
                ProgressView()
            }
        }
        .task {
            if store.symbols.isEmpty {
                await store.send(.loadSymbols).value
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
    .environment(AppStore.preview)
}
