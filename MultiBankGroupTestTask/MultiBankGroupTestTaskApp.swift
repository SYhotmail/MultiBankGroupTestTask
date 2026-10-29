//
//  MultiBankGroupTestTaskApp.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

@main
struct MultiBankGroupTestTaskApp: App {
    @State private var navigationViewModel = StockSymbolsNavigationViewModel(market: .live)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StockSymbolsNavigationView(viewModel: navigationViewModel)
                .task { await navigationViewModel.observeFeed() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: Task { await navigationViewModel.appDidEnterBackground() }
            case .active: Task { await navigationViewModel.appDidBecomeActive() }
            default: break
            }
        }
    }
}

extension StockMarketModel {
    /// Composition root: bundled symbols priced by the Postman echo WebSocket.
    static var live: StockMarketModel { preview }

    /// Previews use the live wiring; the feed stays idle until Start is tapped.
    static var preview: StockMarketModel {
        let priceFeedURL = URL(string: "wss://ws.postman-echo.com/raw")!

        return StockMarketModel(provider: BundledStockSymbolsRepository(), feed: WebSocketPriceFeed(url: priceFeedURL))
    }
}
