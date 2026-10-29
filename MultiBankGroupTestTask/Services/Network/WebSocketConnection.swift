//
//  WebSocketConnection.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

/// Text-message WebSocket transport. Abstracted so the price feed can be tested without a network.
/// `Sendable`: the feed's actor and its echo watchdog both use the same connection.
protocol WebSocketConnection: AnyObject, Sendable {
    /// Opens the socket and returns once the server has answered.
    func connect() async throws
    func send(_ message: String) async throws
    func receive() async throws -> String
    /// Closes the socket. Pending `receive()` calls fail.
    func close()
}

final class URLSessionWebSocketConnection: WebSocketConnection {
    private let task: URLSessionWebSocketTask

    init(url: URL, session: URLSession = .shared) {
        task = session.webSocketTask(with: url)
    }

    func connect() async throws {
        task.resume()
        // A ping round trip confirms the handshake completed.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { @Sendable error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func send(_ message: String) async throws {
        try await task.send(.string(message))
    }

    func receive() async throws -> String {
        switch try await task.receive() {
        case .string(let text):
            return text
        case .data(let data):
            return String(decoding: data, as: UTF8.self)
        @unknown default:
            throw URLError(.cannotDecodeContentData)
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}
