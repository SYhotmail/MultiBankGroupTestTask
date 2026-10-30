//
//  SimulatedFailure.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 30/10/2026.
//

#if DEBUG
import Foundation
import Synchronization

/// Debug-only failures, for seeing alerts, retries and empty screens on demand. Pick one with the launch
/// argument `-simulate <case>`; the scheme lists them all, switched off, under Run > Arguments.
/// Each one wraps a real service at its protocol, so the app's own code runs unchanged.
nonisolated enum SimulatedFailure: String, CaseIterable, Sendable {
    /// The first two loads fail, then loading works.
    case symbolsLoadFails
    /// The first load works, the first pull-to-refresh fails, then refreshing works.
    case symbolsRefreshFails
    /// The first load returns no symbols, then the catalog is back.
    case symbolsEmpty
    /// The first refresh on the detail screen fails, then refreshing works.
    case symbolRefreshFails
    /// Every refresh on the detail screen answers `404`, so the symbol is deleted.
    case symbolDeleted
    /// The first three connection attempts fail, then the feed connects.
    case connectionFails
    /// The first two connections drop after three price updates.
    case connectionDrops
    /// The server never echoes on the first connection, so the feed times out and reconnects.
    case serverSilent

    static var current: SimulatedFailure? {
        UserDefaults.standard.string(forKey: "simulate").flatMap(SimulatedFailure.init(rawValue:))
    }

    func wrapping(_ provider: any StockSymbolsProvider) -> any StockSymbolsProvider {
        SimulatedFailureProvider(failure: self, base: provider)
    }

    /// Makes the feed's connections; each one knows which attempt it is.
    func connections(
        wrapping makeConnection: @escaping @Sendable () -> any WebSocketConnection
    ) -> @Sendable () -> any WebSocketConnection {
        let attempts = Mutex(0)
        return {
            let attempt = attempts.withLock { attempts in
                defer { attempts += 1 }
                return attempts
            }
            return SimulatedFailureConnection(failure: self, attempt: attempt, base: makeConnection())
        }
    }
}

/// Fails or empties the backend's answers as the scenario says.
actor SimulatedFailureProvider: StockSymbolsProvider {
    private let failure: SimulatedFailure
    private let base: any StockSymbolsProvider
    private var symbolsLoads = 0
    private var symbolRefreshes = 0

    init(failure: SimulatedFailure, base: any StockSymbolsProvider) {
        self.failure = failure
        self.base = base
    }

    func fetchStockSymbols() async throws -> [StockSymbolPrice] {
        symbolsLoads += 1
        switch failure {
        case .symbolsLoadFails where symbolsLoads <= 2:
            throw URLError(.notConnectedToInternet)
        case .symbolsRefreshFails where symbolsLoads == 2:
            throw URLError(.timedOut)
        case .symbolsEmpty where symbolsLoads == 1:
            return []
        default:
            return try await base.fetchStockSymbols()
        }
    }

    func fetchStockSymbol(id: String) async throws -> StockSymbolPrice {
        symbolRefreshes += 1
        switch failure {
        case .symbolRefreshFails where symbolRefreshes == 1:
            throw URLError(.timedOut)
        case .symbolDeleted:
            throw StockSymbolsProviderError.notFound(id: id)
        default:
            return try await base.fetchStockSymbol(id: id)
        }
    }
}

/// Fails, drops or silences a connection as the scenario says.
nonisolated final class SimulatedFailureConnection: WebSocketConnection {
    private let failure: SimulatedFailure
    private let attempt: Int
    private let base: any WebSocketConnection
    private let receivedCount = Mutex(0)

    init(failure: SimulatedFailure, attempt: Int, base: any WebSocketConnection) {
        self.failure = failure
        self.attempt = attempt
        self.base = base
    }

    func connect() async throws {
        if failure == .connectionFails, attempt < 3 {
            throw URLError(.cannotConnectToHost)
        }
        try await base.connect()
    }

    func send(_ message: Data) async throws {
        // Unsent, so nothing comes back and `receive()` waits until the feed's echo timeout closes the socket.
        if failure == .serverSilent, attempt == 0 { return }
        try await base.send(message)
    }

    func receive() async throws -> Data {
        let message = try await base.receive()
        let received = receivedCount.withLock { count in
            count += 1
            return count
        }
        if failure == .connectionDrops, attempt < 2, received >= 3 {
            throw URLError(.networkConnectionLost)
        }
        return message
    }

    func close(reason: Data?) {
        base.close(reason: reason)
    }
}
#endif
