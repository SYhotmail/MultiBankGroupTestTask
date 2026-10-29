//
//  StockSymbolDetailView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolDetailView: View {
    let viewModel: StockSymbolDetailViewModel

    var body: some View {
        let symbol = viewModel.symbol
        let quote = viewModel.quote

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

                if let updatedAt = quote.updatedAt {
                    Text("Updated \(updatedAt, format: .dateTime.hour().minute().second())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
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
        .toolbar { FeedToolbar(connectionState: viewModel.connectionState, toggleFeed: viewModel.toggleFeed) }
    }
}

#Preview {
    NavigationStack {
        StockSymbolDetailView(viewModel: StockSymbolDetailViewModel(symbol: StockSymbol.catalog[0], market: .preview))
    }
}
