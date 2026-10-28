//
//  FeedToggleButton.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

/// Start/Stop control for the price feed, shared by the list and detail screens.
struct FeedToggleButton: ToolbarContent {
    let store: StockPriceStore

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(store.isFeedRunning ? "Stop" : "Start", action: store.toggleFeed)
        }
    }
}
