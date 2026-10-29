//
//  WebSocketPriceFeedTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WebSocketPriceFeedTests {
    /// - Parameter configure: Called for each new connection with its zero-based index.
    private func makeFeed(
        echoTimeout: Duration = .seconds(10),
        reconnectDelay: Duration = .milliseconds(5),
        configure: @escaping (EchoWebSocketConnection, Int) -> Void = { _, _ in }
    ) -> (WebSocketPriceFeed, () -> [EchoWebSocketConnection]) {
        var created: [EchoWebSocketConnection] = []
        let generator = PriceUpdateGenerator(symbols: StockSymbol.catalog, rng: SeededRandomNumberGenerator(seed: 1))
        let feed = WebSocketPriceFeed(
            generator: generator,
            updateInterval: .milliseconds(5),
            echoTimeout: echoTimeout,
            reconnectPolicy: ReconnectPolicy(initialDelay: reconnectDelay, maxDelay: max(reconnectDelay, .milliseconds(20)))
        ) {
            let connection = EchoWebSocketConnection()
            configure(connection, created.count)
            created.append(connection)
            return connection
        }
        return (feed, { created })
    }

    /// Next connection state change, skipping price updates.
    private func nextState(_ events: inout AsyncStream<PriceFeedEvent>.Iterator) async -> ConnectionState? {
        while let event = await events.next() {
            if case .connectionChanged(let state) = event { return state }
        }
        return nil
    }

    @Test func startConnectsAndPublishesEchoedUpdates() async throws {
        let (feed, connections) = makeFeed()
        var events = feed.events.makeAsyncIterator()

        feed.start()

        #expect(await events.next() == .connectionChanged(.connecting))
        #expect(await events.next() == .connectionChanged(.connected))
        guard case .priceUpdates(let updates) = await events.next() else {
            Issue.record("Expected price updates")
            return
        }
        let sent = try JSONDecoder().decode([PriceUpdate].self, from: Data(connections()[0].sentMessages[0].utf8))
        #expect(updates == sent)
        #expect(!updates.isEmpty)
    }

    @Test func stopDisconnectsAndClosesTheSocket() async {
        let (feed, connections) = makeFeed()
        var events = feed.events.makeAsyncIterator()
        feed.start()
        _ = await events.next() // connecting
        _ = await events.next() // connected

        feed.stop()

        var next = await events.next()
        // Updates already in flight may arrive first; the next state change must be a disconnect.
        while case .priceUpdates = next { next = await events.next() }
        #expect(next == .connectionChanged(.disconnected))
        #expect(connections()[0].isClosed)
    }

    @Test func feedCanBeRestartedWithAFreshConnection() async {
        let (feed, connections) = makeFeed()
        var events = feed.events.makeAsyncIterator()
        feed.start()
        _ = await events.next() // connecting
        _ = await events.next() // connected
        feed.stop()

        feed.start()

        var states: [ConnectionState] = []
        while states.last != .connected, let event = await events.next() {
            if case .connectionChanged(let state) = event { states.append(state) }
        }
        #expect(states == [.disconnected, .connecting, .connected])
        #expect(connections().count == 2)
    }

    @Test func connectFailureRetriesUntilConnected() async {
        let (feed, connections) = makeFeed { connection, index in
            if index < 2 { connection.connectError = TestError() }
        }
        var events = feed.events.makeAsyncIterator()

        feed.start()

        // Failures keep the feed in `connecting` rather than reporting a disconnect.
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)
        #expect(connections().count == 3)
    }

    @Test func droppedConnectionReconnects() async {
        let (feed, connections) = makeFeed()
        var events = feed.events.makeAsyncIterator()
        feed.start()
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)

        connections()[0].close() // the server drops the socket

        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)
        #expect(connections().count == 2)
    }

    @Test func silentServerTimesOutAndReconnects() async {
        let (feed, connections) = makeFeed(echoTimeout: .milliseconds(20)) { connection, index in
            connection.isSilent = index == 0
        }
        var events = feed.events.makeAsyncIterator()
        feed.start()
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)

        #expect(await nextState(&events) == .connecting)
        #expect(connections()[0].isClosed)
        #expect(await nextState(&events) == .connected)
    }

    @Test func stopDuringBackoffEndsRetries() async {
        let (feed, connections) = makeFeed { connection, _ in connection.connectError = TestError() }
        var events = feed.events.makeAsyncIterator()
        feed.start()
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connecting) // first failure, now backing off

        feed.stop()
        #expect(await nextState(&events) == .disconnected)

        let attempts = connections().count
        try? await Task.sleep(for: .milliseconds(100))
        #expect(connections().count == attempts)
    }

    @Test func suspendDisconnectsAndResumeReconnects() async {
        let (feed, connections) = makeFeed()
        var events = feed.events.makeAsyncIterator()
        feed.start()
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)

        feed.suspend()
        #expect(await nextState(&events) == .disconnected)
        #expect(connections()[0].isClosed)

        feed.resume()
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)
        #expect(connections().count == 2)
    }

    @Test func resumeDoesNotStartAStoppedFeed() async {
        let (feed, connections) = makeFeed()
        feed.start()
        feed.stop()
        feed.suspend()

        feed.resume()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(connections().isEmpty)
    }

    @Test func startWhileSuspendedWaitsForResume() async {
        let (feed, connections) = makeFeed()
        feed.suspend()

        feed.start()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(connections().isEmpty)

        feed.resume()
        var events = feed.events.makeAsyncIterator()
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)
    }

    @Test func malformedEchoIsIgnoredWithoutDroppingTheConnection() async {
        let (feed, connections) = makeFeed { connection, _ in connection.replyOverride = "not json" }
        var events = feed.events.makeAsyncIterator()
        feed.start()
        _ = await events.next() // connecting
        _ = await events.next() // connected

        // Let several exchange cycles run, then stop: the only event must be our own disconnect.
        while connections()[0].sentMessages.count < 3 {
            try? await Task.sleep(for: .milliseconds(5))
        }
        feed.stop()

        #expect(await events.next() == .connectionChanged(.disconnected))
    }

    @Test func outageReportsConnectionLostOnce() async {
        let (feed, _) = makeFeed { connection, index in
            if index < 3 { connection.connectError = TestError() }
        }
        var events = feed.events.makeAsyncIterator()
        feed.start()

        var lostCount = 0
        while let event = await events.next(), event != .connectionChanged(.connected) {
            if event == .connectionLost { lostCount += 1 }
        }
        #expect(lostCount == 1)
    }

    @Test func reconnectSkipsTheBackoffWait() async {
        let (feed, _) = makeFeed(reconnectDelay: .seconds(60)) { connection, index in
            if index == 0 { connection.connectError = TestError() }
        }
        var events = feed.events.makeAsyncIterator()
        feed.start()
        while let event = await events.next(), event != .connectionLost {}

        // Without reconnect() the next attempt would wait about a minute.
        feed.reconnect()

        var states: [ConnectionState] = []
        while states.last != .connected, let state = await nextState(&events) { states.append(state) }
        #expect(!states.contains(.disconnected))
    }

    @Test func reconnectDoesNotStartAStoppedFeed() async {
        let (feed, connections) = makeFeed()

        feed.reconnect()

        try? await Task.sleep(for: .milliseconds(50))
        #expect(connections().isEmpty)
    }

    @Test func updatesFollowTheTrackedSymbols() async {
        let (feed, _) = makeFeed()
        feed.track([.fixture("ZZZ", price: 1)])
        var events = feed.events.makeAsyncIterator()
        feed.start()

        while let event = await events.next() {
            guard case .priceUpdates(let updates) = event else { continue }
            #expect(updates.map(\.symbol) == ["ZZZ"])
            break
        }
    }

    @Test func emptySymbolListSendsNothing() async {
        let (feed, connections) = makeFeed()
        feed.track([])
        var events = feed.events.makeAsyncIterator()
        feed.start()
        #expect(await nextState(&events) == .connecting)
        #expect(await nextState(&events) == .connected)

        try? await Task.sleep(for: .milliseconds(50))
        #expect(connections()[0].sentMessages.isEmpty)
    }
}


struct ReconnectPolicyTests {
    private let policy = ReconnectPolicy(initialDelay: .seconds(1), maxDelay: .seconds(30))

    @Test func delayDoublesUntilCapped() {
        let delays = (1...7).map { policy.delay(afterFailures: $0, jitter: 1) }
        #expect(delays == [1, 2, 4, 8, 16, 30, 30].map { .seconds($0) })
    }

    @Test func jitterScalesTheDelay() {
        #expect(policy.delay(afterFailures: 3, jitter: 0.5) == .seconds(2))
    }

    @Test func hugeFailureCountsStayCapped() {
        #expect(policy.delay(afterFailures: 10_000, jitter: 1) == .seconds(30))
    }
}
