//
//  StockSymbolRowView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 30/10/2026.
//

import SwiftUI

struct StockSymbolRowView: View {
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
