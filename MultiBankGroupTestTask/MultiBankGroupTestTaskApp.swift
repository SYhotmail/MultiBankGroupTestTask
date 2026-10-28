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

    /// Composition root: the catalog symbols fed by the Postman echo WebSocket.
    static var live: StockPriceStore {
        StockPriceStore(symbols: StockSymbol.catalog, feed: WebSocketPriceFeed(url: priceFeedURL, symbols: StockSymbol.catalog))
    }

    /// Previews use the live wiring; the feed stays idle until Start is tapped.
    static var preview: StockPriceStore { live }
}
