//
//  FeedMessageCodecTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// Pins the WebSocket message format, so a change to it is a deliberate, visible decision.
struct FeedMessageCodecTests {
    private let codec = FeedMessageCodec()
    private let updates = [
        PriceUpdate(symbol: "AAPL", price: 229.1, timestamp: .fixture),
        PriceUpdate(symbol: "MSFT", price: 415.2, timestamp: .fixture),
    ]

    @Test func updatesRoundTrip() throws {
        let data = try codec.encode(updates)
        #expect(try codec.decode(data) == updates)
    }

    @Test func updatesAreAPlainArrayWithISO8601Dates() throws {
        let data = try codec.encode(updates)

        let json = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(json.count == 2)
        #expect(json[0]["symbol"] as? String == "AAPL")
        #expect(json[0]["timestamp"] as? String == "2027-01-15T08:00:00Z")
    }

    @Test func decodesAMessageWrittenByTheServer() throws {
        let text = #"[{"symbol":"NVDA","price":135.6,"timestamp":"2027-01-15T08:00:00Z"}]"#

        #expect(try codec.decode(Data(text.utf8)) == [PriceUpdate(symbol: "NVDA", price: 135.6, timestamp: .fixture)])
    }

    @Test(arguments: [
        "not json",
        #"{"type":"heartbeat"}"#,                                       // an object, not a price array
        #"[{"symbol":"AAPL"}]"#,                                        // update missing fields
        #"[{"symbol":"AAPL","price":1,"timestamp":12345}]"#,            // non-ISO date
    ])
    func anythingElseFailsToDecode(text: String) {
        #expect(throws: (any Error).self) { try codec.decode(Data(text.utf8)) }
    }
}
