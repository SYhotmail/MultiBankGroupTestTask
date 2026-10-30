//
//  SimulatedFailureTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 30/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

struct SimulatedFailureTests {
    private let catalog: [StockSymbolPrice] = [.fixture("AAA", price: 10)]

    private func provider(_ failure: SimulatedFailure) -> any StockSymbolsProvider {
        failure.wrapping(FakeStockSymbolsProvider(result: .success(catalog)))
    }

    private func connection(_ failure: SimulatedFailure, attempt: Int) -> SimulatedFailureConnection {
        SimulatedFailureConnection(failure: failure, attempt: attempt, base: EchoWebSocketConnection())
    }

    @Test func symbolsLoadFailsTwiceThenWorks() async throws {
        let provider = provider(.symbolsLoadFails)

        await #expect(throws: URLError.self) { try await provider.fetchStockSymbols() }
        await #expect(throws: URLError.self) { try await provider.fetchStockSymbols() }
        #expect(try await provider.fetchStockSymbols() == catalog)
    }

    @Test func symbolsAreEmptyOnlyOnTheFirstLoad() async throws {
        let provider = provider(.symbolsEmpty)

        #expect(try await provider.fetchStockSymbols().isEmpty)
        #expect(try await provider.fetchStockSymbols() == catalog)
    }

    @Test func symbolRefreshFailsOnceThenWorks() async throws {
        let provider = provider(.symbolRefreshFails)

        await #expect(throws: URLError.self) { try await provider.fetchStockSymbol(id: "AAA") }
        #expect(try await provider.fetchStockSymbol(id: "AAA") == catalog[0])
    }

    @Test func symbolDeletedAlwaysAnswersNotFound() async {
        let provider = provider(.symbolDeleted)

        await #expect(throws: StockSymbolsProviderError.notFound(id: "AAA")) {
            try await provider.fetchStockSymbol(id: "AAA")
        }
    }

    @Test func connectionFailsForTheFirstThreeAttempts() async throws {
        await #expect(throws: URLError.self) { try await connection(.connectionFails, attempt: 2).connect() }
        try await connection(.connectionFails, attempt: 3).connect()
    }

    @Test func connectionDropsOnTheThirdMessage() async throws {
        let connection = connection(.connectionDrops, attempt: 0)

        for _ in 0..<3 { try await connection.send(Data("[]".utf8)) }
        _ = try await connection.receive()
        _ = try await connection.receive()
        await #expect(throws: URLError.self) { try await connection.receive() }
    }

    @Test func silentServerSendsNothing() async throws {
        let echo = EchoWebSocketConnection()
        let connection = SimulatedFailureConnection(failure: .serverSilent, attempt: 0, base: echo)

        try await connection.send(Data("[]".utf8))

        #expect(echo.sentMessages.isEmpty)
    }

    @Test func eachConnectionKnowsItsAttempt() async throws {
        let makeConnection = SimulatedFailure.connectionFails.connections { EchoWebSocketConnection() }

        for _ in 0..<3 {
            await #expect(throws: URLError.self) { try await makeConnection().connect() }
        }
        try await makeConnection().connect()
    }
}
