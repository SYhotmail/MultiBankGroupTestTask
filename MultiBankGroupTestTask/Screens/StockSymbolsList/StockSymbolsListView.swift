//
//  StockSymbolsListView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsListView: View {
    @Bindable var viewModel: StockSymbolsListViewModel
    /// Ticker of the selected row; drives the split view's detail column.
    @Binding var selection: String?

    var body: some View {
        // Rows live in a child view so price ticks don't rebuild the toolbar (and dismiss the sort menu).
        StockSymbolsList(viewModel: viewModel, selection: $selection)
            .navigationTitle("Stocks")
            .toolbar {
                FeedToolbar(connectionState: viewModel.connectionState, toggleFeed: viewModel.toggleFeed)
                ToolbarItem(placement: .primaryAction) {
                    Menu("Sort", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort by", selection: $viewModel.sortOrder) {
                            Label("Price", systemImage: "dollarsign").tag(StockSymbolsListViewModel.SortOrder.price)
                            Label("Price Change", systemImage: "plusminus").tag(StockSymbolsListViewModel.SortOrder.priceChange)
                        }
                    }
                }
            }
    }
}

private struct StockSymbolsList: View {
    let viewModel: StockSymbolsListViewModel
    @Binding var selection: String?

    var body: some View {
        let rows = viewModel.rows
        List(rows, selection: $selection) { row in
            NavigationLink(value: row.id) {
                StockSymbolRowView(symbol: row.symbol, quote: row.quote)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.rowsId)
        .refreshable { await viewModel.refresh() }
        .overlay {
            if viewModel.showsLoadingIndicator {
                ProgressView()
            } else if viewModel.showsEmptyState {
                ContentUnavailableView {
                    Label("No Symbols", systemImage: "chart.line.downtrend.xyaxis")
                } description: {
                    Text("Pull down or tap Retry to try again.")
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.load() }
                    }
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }
}

#Preview {
    NavigationStack {
        StockSymbolsListView(viewModel: StockSymbolsNavigationViewModel.preview.listViewModel, selection: .constant(nil))
    }
}
