//
//  MultiBankGroupTestTaskApp.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

@main
struct MultiBankGroupTestTaskApp: App {
    @State private var market: StockMarketModel
    @State private var navigationViewModel: StockSymbolsNavigationViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let market = StockMarketModel.live
        _market = State(initialValue: market)
        _navigationViewModel = State(initialValue: StockSymbolsNavigationViewModel(market: market))
    }

    var body: some Scene {
        WindowGroup {
            StockSymbolsNavigationStackView(viewModel: navigationViewModel)
                .task { await market.observeFeed() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: market.appDidEnterBackground()
            case .active: market.appDidBecomeActive()
            default: break
            }
        }
    }
}

extension StockMarketModel {
    private static let priceFeedURL = URL(string: "wss://ws.postman-echo.com/raw")!

    /// Composition root: bundled symbols priced by the Postman echo WebSocket.
    static var live: StockMarketModel {
        StockMarketModel(repository: BundledSymbolsRepository(), feed: WebSocketPriceFeed(url: priceFeedURL))
    }

    /// Previews use the live wiring; the feed stays idle until Start is tapped.
    static var preview: StockMarketModel { live }
}
