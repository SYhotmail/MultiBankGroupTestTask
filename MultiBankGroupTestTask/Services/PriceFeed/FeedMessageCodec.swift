//
//  FeedMessageCodec.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// The single place that fixes the feed's message format: a JSON array of price updates
/// (UTF-8 bytes) with ISO 8601 dates, e.g. `[{"symbol":"AAPL","price":229.1,"timestamp":"2027-01-15T08:00:00Z"}]`.
/// Anything else fails to decode. Framing is the connection's job; it sends these bytes as text frames.
///
/// Not `Sendable`, because `JSONEncoder` and `JSONDecoder` aren't; whoever does the I/O owns an
/// instance (the feed actor keeps one and reuses it).
nonisolated struct FeedMessageCodec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func encode(_ updates: [PriceUpdate]) throws -> Data {
        try encoder.encode(updates)
    }

    func decode(_ data: Data) throws -> [PriceUpdate] {
        try decoder.decode([PriceUpdate].self, from: data)
    }
}
