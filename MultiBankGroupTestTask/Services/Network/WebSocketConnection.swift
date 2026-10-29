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
    /// Sends UTF-8 encoded text (e.g. JSON) as one WebSocket text frame.
    /// - Throws: `WebSocketConnectionError.invalidUTF8` if the bytes aren't valid UTF-8.
    func send(_ message: Data) async throws
    /// The next message's payload. Binary and text frames are both accepted, so a server that
    /// answers in text frames works too.
    func receive() async throws -> Data
    /// Closes the socket. Pending `receive()` calls fail.
    func close()
}

nonisolated enum WebSocketConnectionError: Error, Equatable {
    /// `send(_:)` was given bytes that aren't valid UTF-8, so they can't go in a text frame.
    case invalidUTF8
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

    func send(_ message: Data) async throws {
        // Text frames, not binary: JSON is text, and the echo server closes the socket on binary frames.
        try await task.send(.string(try Self.textFrame(from: message)))
    }

    /// The text a frame carries; text frames must be valid UTF-8, so refuse rather than mangle.
    static func textFrame(from message: Data) throws -> String {
        guard let text = String(validating: message, as: UTF8.self) else {
            throw WebSocketConnectionError.invalidUTF8
        }
        return text
    }

    func receive() async throws -> Data {
        switch try await task.receive() {
        case .string(let text):
            return Data(text.utf8)
        case .data(let data):
            return data
        @unknown default:
            throw URLError(.cannotDecodeContentData)
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}
