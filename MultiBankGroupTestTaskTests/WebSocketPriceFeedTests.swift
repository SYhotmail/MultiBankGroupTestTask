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
    private func makeFeed(configure: @escaping (EchoWebSocketConnection) -> Void = { _ in }) -> (WebSocketPriceFeed, () -> [EchoWebSocketConnection]) {
        var created: [EchoWebSocketConnection] = []
        let generator = PriceUpdateGenerator(symbols: StockSymbol.catalog, rng: SeededRandomNumberGenerator(seed: 1))
        let feed = WebSocketPriceFeed(generator: generator, updateInterval: .milliseconds(5)) {
            let connection = EchoWebSocketConnection()
            configure(connection)
            created.append(connection)
            return connection
        }
        return (feed, { created })
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

    @Test func connectFailureReportsDisconnectedAndAllowsRetry() async {
        let (feed, connections) = makeFeed { $0.connectError = TestError() }
        var events = feed.events.makeAsyncIterator()

        feed.start()

        #expect(await events.next() == .connectionChanged(.connecting))
        #expect(await events.next() == .connectionChanged(.disconnected))

        feed.start()
        #expect(await events.next() == .connectionChanged(.connecting))
        #expect(connections().count == 2)
    }

    @Test func malformedEchoIsIgnoredWithoutDroppingTheConnection() async {
        let (feed, connections) = makeFeed { $0.replyOverride = "not json" }
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
}
