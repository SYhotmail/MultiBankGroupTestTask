//
//  StockSymbolsNavigationView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsNavigationView: View {
    @Bindable var viewModel: StockSymbolsNavigationViewModel

    var body: some View {
        // Sidebar list + detail column on iPad; collapses to a push-style stack on iPhone.
        NavigationSplitView {
            StockSymbolsListView(viewModel: viewModel.listViewModel, selection: $viewModel.selectedTicker)
                // Wide enough for the title next to the status, Start/Stop and Sort controls.
                .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 480)
        } detail: {
            if let symbol = viewModel.selectedSymbol {
                StockSymbolDetailView(viewModel: viewModel.detailViewModel(for: symbol))
                    .id(symbol.ticker)
            } else {
                ContentUnavailableView("Select a Symbol", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        // Attached at the root so alerts show on whichever screen is visible.
        .alert(
            Text(verbatim: viewModel.alert?.errorDescription ?? ""),
            isPresented: Binding(get: { viewModel.alert != nil }, set: { if !$0 { viewModel.dismissAlert() } }),
            presenting: viewModel.alert
        ) { alert in
            Button("Retry") {
                Task { await viewModel.retry(alert) }
            }
            Button("OK", role: .cancel) {}
        } message: { alert in
            messageText(for: alert)
        }
    }

    private func messageText(for alert: StockSymbolsError) -> Text {
        let message = alert.recoverySuggestion ?? ""
        #if DEBUG
        if let detail = viewModel.alertDebugDescription {
            // Debug builds append the underlying error. It's for developers, so it isn't localized.
            return Text(verbatim: "\(message)\n\n[DEBUG] \(detail)")
        }
        #endif
        return Text(verbatim: message)
    }
}

#Preview {
    StockSymbolsNavigationView(viewModel: .preview)
}
