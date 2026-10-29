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
    let toggleFeed: @MainActor () async -> Void

    var body: some ToolbarContent {
        // iOS 26 wraps toolbar items in a glass bubble; the status reads better as plain text.
        // Earlier versions draw no bubble, so the item needs no change there.
        if #available(iOS 26, *) {
            statusItem.sharedBackgroundVisibility(.hidden)
        } else {
            statusItem
        }

        ToolbarItem(placement: .primaryAction) {
            let isRunning = connectionState != .disconnected
            Button(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill") {
                Task { await toggleFeed() }
            }
        }
    }

    private var statusItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ConnectionStatusView(state: connectionState)
                .fixedSize()
        }
    }
}
