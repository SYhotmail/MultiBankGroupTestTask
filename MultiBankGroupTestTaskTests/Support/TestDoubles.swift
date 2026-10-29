//
//  TestDoubles.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Synchronization
@testable import MultiBankGroupTestTask

/// Deterministic RNG (SplitMix64) so random-driven code is reproducible on CI.
struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
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
/// Thread-safe, since the feed actor and its echo watchdog call it concurrently.
final class EchoWebSocketConnection: WebSocketConnection {
    private struct State {
        var connectError: (any Error)?
        var replyOverride: String?
        var isSilent = false
        var sentMessages: [String] = []
        var isClosed = false
        var pending: [String] = []
        var silentReceive: CheckedContinuation<String, any Error>?
    }

    private let state = Mutex(State())

    var connectError: (any Error)? {
        get { state.withLock { $0.connectError } }
        set { state.withLock { $0.connectError = newValue } }
    }

    /// When set, `receive()` returns this instead of the echo.
    var replyOverride: String? {
        get { state.withLock { $0.replyOverride } }
        set { state.withLock { $0.replyOverride = newValue } }
    }

    /// When set, `receive()` never answers; it only fails once the socket is closed.
    var isSilent: Bool {
        get { state.withLock { $0.isSilent } }
        set { state.withLock { $0.isSilent = newValue } }
    }

    var sentMessages: [String] { state.withLock { $0.sentMessages } }
    var isClosed: Bool { state.withLock { $0.isClosed } }

    func connect() async throws {
        if let error = connectError { throw error }
    }

    func send(_ message: String) async throws {
        try state.withLock { state in
            guard !state.isClosed else { throw TestError() }
            state.sentMessages.append(message)
            state.pending.append(message)
        }
    }

    func receive() async throws -> String {
        let reply: String? = try state.withLock { state in
            guard !state.isClosed else { throw TestError() }
            guard !state.isSilent else { return nil }
            guard !state.pending.isEmpty else { throw TestError() }
            let echo = state.pending.removeFirst()
            return state.replyOverride ?? echo
        }
        if let reply { return reply }
        return try await withCheckedThrowingContinuation { continuation in
            state.withLock { state in
                // close() may have run since the check above; fail right away instead of hanging.
                if state.isClosed {
                    continuation.resume(throwing: TestError())
                } else {
                    state.silentReceive = continuation
                }
            }
        }
    }

    func close() {
        let pending = state.withLock { state in
            state.isClosed = true
            defer { state.silentReceive = nil }
            return state.silentReceive
        }
        pending?.resume(throwing: TestError())
    }
}

/// Records every connection the feed creates, in order.
final class ConnectionLog: Sendable {
    private let connections = Mutex<[EchoWebSocketConnection]>([])

    var all: [EchoWebSocketConnection] { connections.withLock { $0 } }

    func append(_ connection: EchoWebSocketConnection) -> Int {
        connections.withLock { list in
            list.append(connection)
            return list.count - 1
        }
    }
}

actor FakePriceFeed: PriceFeed {
    nonisolated let events: AsyncStream<PriceFeedEvent>
    nonisolated let continuation: AsyncStream<PriceFeedEvent>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var suspendCount = 0
    private(set) var resumeCount = 0
    private(set) var reconnectCount = 0
    private(set) var trackedSymbols: [StockSymbolPrice] = []

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func suspend() { suspendCount += 1 }
    func resume() { resumeCount += 1 }
    func reconnect() { reconnectCount += 1 }
    func track(_ symbolPrices: [StockSymbolPrice]) { trackedSymbols = symbolPrices }
}

actor FakeStockSymbolsRepository: StockSymbolsRepository {
    private var result: Result<[StockSymbolPrice], any Error>
    /// When set, answers `fetchStockSymbol(id:)`; otherwise it looks the id up in `result`.
    private var symbolResult: Result<StockSymbolPrice, any Error>?

    init(result: Result<[StockSymbolPrice], any Error> = .success([])) {
        self.result = result
    }

    func setResult(_ result: Result<[StockSymbolPrice], any Error>) {
        self.result = result
    }

    func setSymbolResult(_ result: Result<StockSymbolPrice, any Error>) {
        symbolResult = result
    }

    func fetchStockSymbols() async throws -> [StockSymbolPrice] {
        try result.get()
    }

    func fetchStockSymbol(id: String) async throws -> StockSymbolPrice {
        if let symbolResult { return try symbolResult.get() }
        guard let match = try result.get().first(where: { $0.symbol.ticker == id }) else {
            throw StockSymbolsRepositoryError.notFound(id: id)
        }
        return match
    }
}

extension Date {
    /// Fixed moment for deterministic timestamps; whole seconds, so it survives an ISO 8601 round trip.
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
    /// When fixture reference prices were observed: a day before live updates.
    static let referenceFixture = fixture.addingTimeInterval(-86_400)
}

extension StockSymbol {
    static func fixture(_ ticker: String) -> StockSymbol {
        StockSymbol(ticker: ticker, name: "\(ticker) Inc.", summary: "")
    }
}

extension StockSymbolPrice {
    static func fixture(
        _ ticker: String,
        name: String? = nil,
        price: Decimal,
        at timestamp: Date = .referenceFixture
    ) -> StockSymbolPrice {
        let symbol = StockSymbol(ticker: ticker, name: name ?? "\(ticker) Inc.", summary: "")
        return StockSymbolPrice(symbol: symbol, price: price, timestamp: timestamp)
    }
}
