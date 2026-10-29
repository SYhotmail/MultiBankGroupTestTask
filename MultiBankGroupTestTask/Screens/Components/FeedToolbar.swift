//
//  FeedToolbar.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

/// Connection status and Start/Stop control, shared by the list and detail screens.
struct FeedToolbar: ToolbarContent {
    let connectionState: ConnectionState
    let toggleFeed: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ConnectionStatusView(state: connectionState)
                .fixedSize()
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .primaryAction) {
            let isRunning = connectionState != .disconnected
            Button(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill", action: toggleFeed)
        }
    }
}
