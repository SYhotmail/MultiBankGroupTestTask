//
//  StockSymbolDetailView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolDetailView: View {
    let viewModel: StockSymbolDetailViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        let symbol = viewModel.symbol
        let quote = viewModel.quote

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(symbol.name)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if let quote {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        PriceText(price: quote.price)
                            .font(.largeTitle.bold())
                        PriceChangeIndicator(quote: quote)
                            .font(.title3)
                    }

                    Text("Updated \(quote.updatedAt, format: Self.updateTimeFormat(for: quote.updatedAt))")
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
        .refreshable { await viewModel.refresh() }
        .navigationTitle(symbol.ticker)
        .toolbar {
            // Side by side (iPad, regular width) the list's toolbar already has these controls.
            if horizontalSizeClass != .regular {
                FeedToolbar(connectionState: viewModel.connectionState, toggleFeed: viewModel.toggleFeed)
            }
        }
    }

    /// Time only for today's updates; older ones (e.g. a previous close) also show the date.
    private static func updateTimeFormat(for date: Date) -> Date.FormatStyle {
        Calendar.current.isDateInToday(date)
            ? .dateTime.hour().minute().second()
            : .dateTime.day().month().hour().minute()
    }
}

#Preview {
    NavigationStack {
        StockSymbolDetailView(viewModel: StockSymbolsNavigationViewModel.preview.detailViewModel(for: StockSymbolPrice.catalog[0].symbol))
    }
}
