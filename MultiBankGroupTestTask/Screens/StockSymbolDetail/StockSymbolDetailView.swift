//
//  StockSymbolDetailView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolDetailView: View {
    @Environment(AppStore.self) private var store
    let symbol: StockSymbol

    var body: some View {
        let quote = store.state.quote(for: symbol)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(symbol.name)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    PriceText(price: quote.price)
                        .font(.largeTitle.bold())
                    PriceChangeIndicator(quote: quote)
                        .font(.title3)
                }

                Text("About")
                    .font(.headline)
                    .padding(.top)
                Text(symbol.summary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(symbol.ticker)
        .toolbar { FeedToolbar(store: store) }
    }
}

#Preview {
    NavigationStack {
        StockSymbolDetailView(symbol: StockSymbol.catalog[0])
    }
    .environment(AppStore.preview)
}
