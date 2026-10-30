//
//  NetworkMonitorProvider.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 30/10/2026.
//

import Foundation
import Network

/// Reports whether the device can reach the network. Abstracted so the reaction can be tested offline.
nonisolated protocol NetworkMonitorProvider: Sendable {
    /// `true` when online. The first value is the current state; later ones are changes.
    var isOnlineUpdates: AsyncStream<Bool> { get }
}

nonisolated struct NetworkMonitorService: NetworkMonitorProvider {
    var isOnlineUpdates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "NetworkMonitorService"))
        }
    }
}
