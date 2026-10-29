//
//  WebSocketConnectionTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// Text frames must carry valid UTF-8; the connection checks before sending.
struct WebSocketConnectionTests {
    @Test func validUTF8BecomesTheFrameText() throws {
        let json = #"{"type":"prices","payload":[]}"#
        #expect(try URLSessionWebSocketConnection.textFrame(from: Data(json.utf8)) == json)
    }

    @Test func invalidUTF8IsRefused() {
        let invalid = Data([0x7B, 0xFF, 0xFE, 0x7D])   // "{", two bytes that are never valid UTF-8, "}"
        #expect(throws: WebSocketConnectionError.invalidUTF8) {
            try URLSessionWebSocketConnection.textFrame(from: invalid)
        }
    }

    @Test func codecOutputIsAlwaysAValidTextFrame() throws {
        let message = FeedMessage.prices([PriceUpdate(symbol: "AAPL", price: 229.1, timestamp: .fixture)])
        let data = try FeedMessageCodec().encode(message)
        #expect(try !URLSessionWebSocketConnection.textFrame(from: data).isEmpty)
    }
}
