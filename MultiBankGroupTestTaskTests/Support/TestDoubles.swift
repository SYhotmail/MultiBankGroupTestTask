//
//  TestDoubles.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import OSLog
import Synchronization
@testable import MultiBankGroupTestTask

/// Repeatable random numbers: the same seed always gives the same sequence, so random-driven code
/// behaves identically on every CI run. This is the standard SplitMix64 algorithm: it advances a
/// counter by a fixed step, then scrambles the counter into the number it returns.
struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    // The published SplitMix64 constants. Changing them changes every seeded sequence.
    private static let step: UInt64 = 0x9E37_79B9_7F4A_7C15
    private static let firstMultiplier: UInt64 = 0xBF58_476D_1CE4_E5B9
    private static let secondMultiplier: UInt64 = 0x94D0_49BB_1331_11EB

    private var counter: UInt64

    init(seed: UInt64) {
        counter = seed
    }

    mutating func next() -> UInt64 {
        // `&+` and `&*` wrap on overflow, which is what the algorithm wants.
        counter &+= Self.step
        return Self.scramble(counter)
    }

    /// Mixes the bits, so consecutive counters give unrelated numbers.
    private static func scramble(_ value: UInt64) -> UInt64 {
        var mixed = value
        mixed = (mixed ^ (mixed >> 30)) &* firstMultiplier
        mixed = (mixed ^ (mixed >> 27)) &* secondMultiplier
        return mixed ^ (mixed >> 31)
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
        var sentMessages: [Data] = []
        var isClosed = false
        var pending: [Data] = []
        var silentReceive: CheckedContinuation<Data, any Error>?
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

    var sentMessages: [Data] { state.withLock { $0.sentMessages } }
    var isClosed: Bool { state.withLock { $0.isClosed } }

    func connect() async throws {
        if let error = connectError { throw error }
    }

    func send(_ message: Data) async throws {
        try state.withLock { state in
            guard !state.isClosed else { throw TestError() }
            state.sentMessages.append(message)
            state.pending.append(message)
        }
    }

    func receive() async throws -> Data {
        let reply: Data? = try state.withLock { state in
            guard !state.isClosed else { throw TestError() }
            guard !state.isSilent else { return nil }
            guard !state.pending.isEmpty else { throw TestError() }
            let echo = state.pending.removeFirst()
            return state.replyOverride.map { Data($0.utf8) } ?? echo
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

    func close(reason: Data?) {
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

actor FakePriceFeed: PriceFeedProvider {
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

/// Network state driven by the test: yield `true` or `false`, then `finish()` to end the observer.
final class FakeNetworkMonitor: NetworkMonitorProvider {
    let isOnlineUpdates: AsyncStream<Bool>
    let continuation: AsyncStream<Bool>.Continuation

    init() {
        (isOnlineUpdates, continuation) = AsyncStream.makeStream()
    }
}

actor FakeStockSymbolsProvider: StockSymbolsProvider {
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
            throw StockSymbolsProviderError.notFound(id: id)
        }
        return match
    }
}

/// Polls `condition` until it holds or `timeout` passes; for work the code under test starts in its own task.
func eventually(timeout: Duration = .seconds(2), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return await condition()
}

extension Logger {
    /// Discards everything: tests assert on state, not log output. Built on `OSLog.disabled` because
    /// the SDK's `Logger.disabled` is missing from the older OS versions the tests also run on.
    static let empty = Logger(OSLog.disabled)
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
