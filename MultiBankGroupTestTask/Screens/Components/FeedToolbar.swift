//
//  FeedToolbar.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

/// Connection status and Start/Stop control, shared by the list and detail screens.
struct FeedToolbar: ToolbarContent {
    let store: AppStore

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ConnectionStatusView(state: store.connectionState)
                .fixedSize()
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .primaryAction) {
            let isRunning = store.connectionState.isActive
            Button(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill") {
                store.send(.toggleFeedTapped)
            }
        }
    }
}
