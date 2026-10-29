//
//  PriceFeed.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

enum PriceFeedEvent: Equatable, Sendable {
    case connectionChanged(ConnectionState)
    case priceUpdates([PriceUpdate])
    /// The live connection failed. Sent once per outage; the feed keeps retrying on its own.
    case connectionLost
}

/// A source of live prices that can be started and stopped. An actor, so feed work never runs on
/// the main thread; callers interact with it asynchronously.
protocol PriceFeed: Actor {
    /// Single-consumer stream that lives as long as the feed, across start/stop cycles.
    nonisolated var events: AsyncStream<PriceFeedEvent> { get }
    /// User intent: keep the feed running, reconnecting as needed.
    func start()
    /// User intent: stop the feed.
    func stop()
    /// App went to the background: drop the connection but remember whether the feed was running.
    func suspend()
    /// App is active again: reconnect if the feed was running before `suspend()`.
    func resume()
    /// Reconnects immediately if the feed is running, skipping any backoff wait.
    func reconnect()
    /// Generates updates for these symbols from now on.
    func track(_ symbols: [StockSymbol])
}

/// Delay before reconnecting: exponential growth from `initialDelay`, capped at `maxDelay`.
struct ReconnectPolicy: Sendable {
    var initialDelay: Duration = .seconds(1)
    var maxDelay: Duration = .seconds(30)

    /// - Parameter jitter: Multiplier in `0.5...1` that spreads out clients reconnecting at the same time.
    func delay(afterFailures failures: Int, jitter: Double) -> Duration {
        let exponential = initialDelay * (1 << min(max(failures - 1, 0), 16))
        return min(exponential, maxDelay) * jitter
    }
}

/// Sends generated price updates to an echo WebSocket and publishes what comes back.
///
/// While started (and not suspended) it keeps a session alive: a failed connect, a dropped socket
/// or an echo that doesn't arrive within `echoTimeout` all lead to a reconnect with backoff.
/// Session state, price generation and JSON coding are isolated to this actor, off the main thread.
actor WebSocketPriceFeed: PriceFeed {
    nonisolated let events: AsyncStream<PriceFeedEvent>
    private let continuation: AsyncStream<PriceFeedEvent>.Continuation
    private let makeConnection: @Sendable () -> any WebSocketConnection
    private var generator: PriceUpdateGenerator
    private let updateInterval: Duration
    private let echoTimeout: Duration
    private let reconnectPolicy: ReconnectPolicy
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var isRequested = false
    private var isSuspended = false
    private var connection: (any WebSocketConnection)?
    private var session: Task<Void, Never>?

    init(
        generator: PriceUpdateGenerator,
        updateInterval: Duration = .seconds(2),
        echoTimeout: Duration = .seconds(10),
        reconnectPolicy: ReconnectPolicy = ReconnectPolicy(),
        now: @escaping @Sendable () -> Date = { .now },
        makeConnection: @escaping @Sendable () -> any WebSocketConnection
    ) {
        (events, continuation) = AsyncStream.makeStream()
        self.generator = generator
        self.updateInterval = updateInterval
        self.echoTimeout = echoTimeout
        self.reconnectPolicy = reconnectPolicy
        self.now = now
        self.makeConnection = makeConnection
    }

    init(url: URL) {
        self.init(generator: PriceUpdateGenerator(symbols: [])) {
            URLSessionWebSocketConnection(url: url)
        }
    }

    func start() {
        isRequested = true
        startSessionIfNeeded()
    }

    func stop() {
        isRequested = false
        endSession()
    }

    func suspend() {
        isSuspended = true
        endSession()
    }

    func resume() {
        isSuspended = false
        startSessionIfNeeded()
    }

    func reconnect() {
        guard session != nil else { return }
        endSession(reportsDisconnect: false)
        startSessionIfNeeded()
    }

    func track(_ symbols: [StockSymbol]) {
        generator.track(symbols)
    }

    private func startSessionIfNeeded() {
        guard isRequested, !isSuspended, session == nil else { return }
        continuation.yield(.connectionChanged(.connecting))
        session = Task { await runSession() }
    }

    private func endSession(reportsDisconnect: Bool = true) {
        guard let session else { return }
        session.cancel()
        self.session = nil
        connection?.close()
        connection = nil
        if reportsDisconnect {
            continuation.yield(.connectionChanged(.disconnected))
        }
    }

    /// Connects and streams updates, reconnecting after failures until the session is cancelled.
    private func runSession() async {
        var failures = 0
        while !Task.isCancelled {
            let connection = makeConnection()
            self.connection = connection
            do {
                try await connection.connect()
                try Task.checkCancellation()
                failures = 0
                continuation.yield(.connectionChanged(.connected))
                while true {
                    try await exchangeUpdates(over: connection)
                    try await Task.sleep(for: updateInterval)
                }
            } catch {
                connection.close()
                // A cancelled session was ended by stop/suspend, which already reported it.
                guard !Task.isCancelled else { return }
                failures += 1
                if failures == 1 {
                    continuation.yield(.connectionLost)
                }
                continuation.yield(.connectionChanged(.connecting))
                try? await Task.sleep(for: reconnectPolicy.delay(afterFailures: failures, jitter: .random(in: 0.5...1)))
            }
        }
    }

    private func exchangeUpdates(over connection: any WebSocketConnection) async throws {
        let updates = generator.next(at: now())
        guard !updates.isEmpty else { return }
        let message = String(decoding: try encoder.encode(updates), as: UTF8.self)
        try await connection.send(message)

        // A silent server never fails `receive()` on its own; closing the socket makes it throw.
        let watchdog = Task { [echoTimeout] in
            try await Task.sleep(for: echoTimeout)
            connection.close()
        }
        defer { watchdog.cancel() }
        let echo = try await connection.receive()
        try Task.checkCancellation()

        // The echo crosses a trust boundary: drop anything that is not a valid update batch.
        guard let echoed = try? decoder.decode([PriceUpdate].self, from: Data(echo.utf8)) else { return }
        continuation.yield(.priceUpdates(echoed))
    }
}
