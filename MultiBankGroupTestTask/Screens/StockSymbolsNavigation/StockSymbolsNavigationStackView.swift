//
//  StockSymbolsNavigationStackView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsNavigationStackView: View {
    @Environment(StockPriceStore.self) private var store

    var body: some View {
        NavigationStack {
            StockSymbolsListView()
                .navigationDestination(for: StockSymbol.self) { symbol in
                    StockSymbolDetailView(symbol: symbol)
                }
        }
        // Attached at the root so alerts show on whichever screen is visible.
        .alert(
            store.alert.map { Text($0.title) } ?? Text(verbatim: ""),
            isPresented: Binding(get: { store.alert != nil }, set: { if !$0 { store.dismissAlert() } }),
            presenting: store.alert
        ) { alert in
            Button("Retry") {
                Task { await store.retry(alert) }
            }
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}

private extension StockPriceStore.Alert {
    var title: LocalizedStringKey {
        switch self {
        case .symbolsUnavailable: "Couldn't Load Symbols"
        case .connectionLost: "Connection Problem"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .symbolsUnavailable: "Check your connection and try again."
        case .connectionLost: "Live prices are unavailable. The app will keep trying to reconnect."
        }
    }
}

#Preview {
    StockSymbolsNavigationStackView()
        .environment(StockPriceStore.preview)
}
