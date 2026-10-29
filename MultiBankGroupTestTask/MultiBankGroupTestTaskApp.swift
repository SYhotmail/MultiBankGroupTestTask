//
//  MultiBankGroupTestTaskApp.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

@main
struct MultiBankGroupTestTaskApp: App {
    @State private var store = StockPriceStore.live
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            StockSymbolsNavigationStackView()
                .environment(store)
                .task { await store.observeFeed() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: store.appDidEnterBackground()
            case .active: store.appDidBecomeActive()
            default: break
            }
        }
    }
}

extension StockPriceStore {
    private static let priceFeedURL = URL(string: "wss://ws.postman-echo.com/raw")!

    /// Composition root: bundled symbols priced by the Postman echo WebSocket.
    static var live: StockPriceStore {
        StockPriceStore(repository: BundledSymbolsRepository(), feed: WebSocketPriceFeed(url: priceFeedURL))
    }

    /// Previews use the live wiring; the feed stays idle until Start is tapped.
    static var preview: StockPriceStore { live }
}
