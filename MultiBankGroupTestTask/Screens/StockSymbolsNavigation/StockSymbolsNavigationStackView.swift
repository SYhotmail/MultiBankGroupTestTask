//
//  StockSymbolsNavigationStackView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsNavigationStackView: View {
    var body: some View {
        NavigationStack {
            StockSymbolsListView()
                .navigationDestination(for: StockSymbol.self) { symbol in
                    StockSymbolDetailView(symbol: symbol)
                }
        }
    }
}

#Preview {
    StockSymbolsNavigationStackView()
        .environment(StockPriceStore.preview)
}
