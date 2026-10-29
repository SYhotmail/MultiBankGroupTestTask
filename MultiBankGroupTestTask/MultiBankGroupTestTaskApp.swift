//
//  MultiBankGroupTestTaskApp.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

@main
struct MultiBankGroupTestTaskApp: App {
    @State private var navigationViewModel = StockSymbolsNavigationViewModel.live
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StockSymbolsNavigationView(viewModel: navigationViewModel)
                .task { await navigationViewModel.observeFeed() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                navigationViewModel.appDidEnterBackground()
            case .active:
                navigationViewModel.appDidBecomeActive()
            default: break
            }
        }
    }
}

extension StockSymbolsNavigationViewModel {
    /// Composition root: bundled symbols priced by the Postman echo WebSocket.
    static var live: StockSymbolsNavigationViewModel { preview }

    /// Previews use the live wiring; the feed stays idle until Start is tapped.
    static var preview: StockSymbolsNavigationViewModel {
        let priceFeedURL = URL(string: "wss://ws.postman-echo.com/raw")!

        return StockSymbolsNavigationViewModel(provider: BundledStockSymbolsRepository(), feed: WebSocketPriceFeed(url: priceFeedURL))
    }
}
