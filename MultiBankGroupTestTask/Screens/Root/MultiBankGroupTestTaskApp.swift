//
//  MultiBankGroupTestTaskApp.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import OSLog
import SwiftUI

@main
struct MultiBankGroupTestTaskApp: App {
    @State private var navigationViewModel = StockSymbolsNavigationViewModel.live
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StockSymbolsNavigationView(viewModel: navigationViewModel)
                .task { await navigationViewModel.observeFeed() }
                .task { await navigationViewModel.observeNetwork() }
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
    private static let priceFeedURL = URL(string: "wss://ws.postman-echo.com/raw")!

    /// Composition root: bundled symbols priced by the Postman echo WebSocket.
    static var live: StockSymbolsNavigationViewModel {
        #if DEBUG
        if let failure = SimulatedFailure.current {
            let url = priceFeedURL
            let makeConnection = failure.connections { URLSessionWebSocketConnection(url: url) }
            return StockSymbolsNavigationViewModel(
                provider: failure.wrapping(BundledStockSymbolsRepository()),
                feed: WebSocketPriceFeedProvider(makeConnection: makeConnection),
                network: NetworkMonitorService(),
                logger: .viewModels
            )
        }
        #endif
        return preview
    }

    /// Previews use the live wiring; the feed stays idle until Start is tapped.
    static var preview: StockSymbolsNavigationViewModel {
        StockSymbolsNavigationViewModel(provider: BundledStockSymbolsRepository(), feed: WebSocketPriceFeedProvider(url: priceFeedURL), network: NetworkMonitorService(), logger: .viewModels)
    }
}
