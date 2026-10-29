//
//  FeedMessageCodecTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// Pins the WebSocket wire format, so a change to it is a deliberate, visible decision.
struct FeedMessageCodecTests {
    private let codec = FeedMessageCodec()
    private let updates = [
        PriceUpdate(symbol: "AAPL", price: 229.1, timestamp: .fixture),
        PriceUpdate(symbol: "MSFT", price: 415.2, timestamp: .fixture),
    ]

    @Test func pricesRoundTrip() throws {
        let data = try codec.encode(.prices(updates))
        #expect(try codec.decode(data) == .prices(updates))
    }

    @Test func pricesUseTheEnvelopeShapeWithISO8601Dates() throws {
        let data = try codec.encode(.prices(updates))

        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["type"] as? String == "prices")
        let payload = try #require(json["payload"] as? [[String: Any]])
        #expect(payload.count == 2)
        #expect(payload[0]["symbol"] as? String == "AAPL")
        #expect(payload[0]["timestamp"] as? String == "2027-01-15T08:00:00Z")
    }

    @Test func decodesAMessageWrittenByTheServer() throws {
        let text = #"{"type":"prices","payload":[{"symbol":"NVDA","price":135.6,"timestamp":"2027-01-15T08:00:00Z"}]}"#

        #expect(try codec.decode(Data(text.utf8)) == .prices([PriceUpdate(symbol: "NVDA", price: 135.6, timestamp: .fixture)]))
    }

    @Test func unknownTypeDecodesInsteadOfFailing() throws {
        let text = #"{"type":"heartbeat","payload":{"sequence":42}}"#
        #expect(try codec.decode(Data(text.utf8)) == .unknown(type: "heartbeat"))
    }

    @Test(arguments: [
        "not json",
        #"{"payload":[]}"#,                                   // missing type
        #"{"type":"prices"}"#,                                 // missing payload
        #"{"type":"prices","payload":[{"symbol":"AAPL"}]}"#,   // update missing fields
        #"{"type":"prices","payload":[{"symbol":"AAPL","price":1,"timestamp":12345}]}"#, // non-ISO date
    ])
    func malformedMessagesFailToDecode(text: String) {
        #expect(throws: (any Error).self) { try codec.decode(Data(text.utf8)) }
    }
}
