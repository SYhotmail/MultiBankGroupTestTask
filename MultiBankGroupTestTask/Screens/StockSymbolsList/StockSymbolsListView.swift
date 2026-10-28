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

        List {
            Section {
                ForEach(store.sortedSymbols) { symbol in
                    NavigationLink(value: symbol) {
                        StockSymbolRow(symbol: symbol, quote: store.quote(for: symbol))
                    }
                }
            } header: {
                VStack(alignment: .leading) {
                    ConnectionStatusView(state: store.connectionState)
                    Picker("Sort by", selection: $store.sortOrder) {
                        Text("Price").tag(StockPriceStore.SortOrder.price)
                        Text("Price Change").tag(StockPriceStore.SortOrder.priceChange)
                    }
                    .pickerStyle(.segmented)
                }
                .textCase(nil)
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .animation(.default, value: store.sortedSymbols)
        .navigationTitle("Stocks")
        .toolbar { FeedToggleButton(store: store) }
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
