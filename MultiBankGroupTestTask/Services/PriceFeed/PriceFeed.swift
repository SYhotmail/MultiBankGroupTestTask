//
//  PriceFeed.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

nonisolated enum PriceFeedEvent: Equatable, Sendable {
    case connectionChanged(ConnectionState)
    case priceUpdates([PriceUpdate])
}

/// A source of live prices that can be started and stopped.
protocol PriceFeed: AnyObject {
    /// Single-consumer stream that lives as long as the feed, across start/stop cycles.
    var events: AsyncStream<PriceFeedEvent> { get }
    func start()
    func stop()
}

/// Sends generated price updates to an echo WebSocket and publishes what comes back.
final class WebSocketPriceFeed: PriceFeed {
    let events: AsyncStream<PriceFeedEvent>
    private let continuation: AsyncStream<PriceFeedEvent>.Continuation
    private let makeConnection: () -> any WebSocketConnection
    private var generator: PriceUpdateGenerator
    private let updateInterval: Duration
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var connection: (any WebSocketConnection)?
    private var session: Task<Void, Never>?

    init(
        generator: PriceUpdateGenerator,
        updateInterval: Duration = .seconds(2),
        makeConnection: @escaping () -> any WebSocketConnection
    ) {
        (events, continuation) = AsyncStream.makeStream()
        self.generator = generator
        self.updateInterval = updateInterval
        self.makeConnection = makeConnection
    }

    convenience init(url: URL, symbols: [StockSymbol]) {
        self.init(generator: PriceUpdateGenerator(symbols: symbols)) {
            URLSessionWebSocketConnection(url: url)
        }
    }

    func start() {
        guard session == nil else { return }
        let connection = makeConnection()
        self.connection = connection
        continuation.yield(.connectionChanged(.connecting))
        session = Task { await run(on: connection) }
    }

    func stop() {
        guard session != nil else { return }
        tearDown()
    }

    private func tearDown() {
        session?.cancel()
        session = nil
        connection?.close()
        connection = nil
        continuation.yield(.connectionChanged(.disconnected))
    }

    private func run(on connection: any WebSocketConnection) async {
        do {
            try await connection.connect()
            try Task.checkCancellation()
            continuation.yield(.connectionChanged(.connected))
            while true {
                try await exchangeUpdates(over: connection)
                try await Task.sleep(for: updateInterval)
            }
        } catch {
            // A stopped session has already torn down; only a failing live session reports here.
            if self.connection === connection {
                tearDown()
            }
        }
    }

    private func exchangeUpdates(over connection: any WebSocketConnection) async throws {
        let message = String(decoding: try encoder.encode(generator.next()), as: UTF8.self)
        try await connection.send(message)
        let echo = try await connection.receive()
        try Task.checkCancellation()
        // The echo crosses a trust boundary: drop anything that is not a valid update batch.
        guard let updates = try? decoder.decode([PriceUpdate].self, from: Data(echo.utf8)) else { return }
        continuation.yield(.priceUpdates(updates))
    }
}
