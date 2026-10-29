//
//  TestDoubles.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
@testable import MultiBankGroupTestTask

/// Deterministic RNG (SplitMix64) so random-driven code is reproducible on CI.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct TestError: Error {}

/// In-memory echo server: every sent message is returned by the next `receive()`.
@MainActor
final class EchoWebSocketConnection: WebSocketConnection {
    var connectError: Error?
    /// When set, `receive()` returns this instead of the echo.
    var replyOverride: String?
    /// When set, `receive()` never answers; it only fails once the socket is closed.
    var isSilent = false
    private(set) var sentMessages: [String] = []
    private(set) var isClosed = false
    private var pending: [String] = []
    private var silentReceive: CheckedContinuation<String, Error>?

    func connect() async throws {
        if let connectError { throw connectError }
    }

    func send(_ message: String) async throws {
        guard !isClosed else { throw TestError() }
        sentMessages.append(message)
        pending.append(message)
    }

    func receive() async throws -> String {
        guard !isClosed else { throw TestError() }
        if isSilent {
            return try await withCheckedThrowingContinuation { silentReceive = $0 }
        }
        guard !pending.isEmpty else { throw TestError() }
        let echo = pending.removeFirst()
        return replyOverride ?? echo
    }

    func close() {
        isClosed = true
        silentReceive?.resume(throwing: TestError())
        silentReceive = nil
    }
}

@MainActor
final class FakePriceFeed: PriceFeed {
    let events: AsyncStream<PriceFeedEvent>
    let continuation: AsyncStream<PriceFeedEvent>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var suspendCount = 0
    private(set) var resumeCount = 0
    private(set) var reconnectCount = 0
    private(set) var trackedSymbols: [StockSymbol] = []

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func suspend() { suspendCount += 1 }
    func resume() { resumeCount += 1 }
    func reconnect() { reconnectCount += 1 }
    func track(_ symbols: [StockSymbol]) { trackedSymbols = symbols }
}

@MainActor
final class FakeSymbolsRepository: SymbolsRepository {
    var result: Result<[StockSymbol], Error> = .success([])

    func fetchSymbols() async throws -> [StockSymbol] {
        try result.get()
    }
}

extension StockSymbol {
    static func fixture(_ ticker: String, price: Decimal) -> StockSymbol {
        StockSymbol(ticker: ticker, name: "\(ticker) Inc.", summary: "", referencePrice: price)
    }
}
