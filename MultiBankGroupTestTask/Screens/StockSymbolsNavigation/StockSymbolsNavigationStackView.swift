//
//  StockSymbolsNavigationStackView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsNavigationStackView: View {
    let viewModel: StockSymbolsNavigationViewModel

    var body: some View {
        NavigationStack {
            StockSymbolsListView(viewModel: viewModel.listViewModel)
                .navigationDestination(for: StockSymbol.self) { symbol in
                    StockSymbolDetailView(viewModel: viewModel.detailViewModel(for: symbol))
                }
        }
        // Attached at the root so alerts show on whichever screen is visible.
        .alert(
            viewModel.alert.map { Text($0.title) } ?? Text(verbatim: ""),
            isPresented: Binding(get: { viewModel.alert != nil }, set: { if !$0 { viewModel.dismissAlert() } }),
            presenting: viewModel.alert
        ) { alert in
            Button("Retry") {
                Task { await viewModel.retry(alert) }
            }
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}

private extension StockMarketModel.Issue {
    var title: LocalizedStringKey {
        switch self {
        case .symbolsUnavailable: "Couldn't Load Symbols"
        case .symbolUnavailable(let ticker): "Couldn't Refresh \(ticker)"
        case .connectionLost: "Connection Problem"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .symbolsUnavailable, .symbolUnavailable: "Check your connection and try again."
        case .connectionLost: "Live prices are unavailable. The app will keep trying to reconnect."
        }
    }
}

#Preview {
    StockSymbolsNavigationStackView(viewModel: StockSymbolsNavigationViewModel(market: .preview))
}
