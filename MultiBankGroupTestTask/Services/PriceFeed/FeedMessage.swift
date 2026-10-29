//
//  FeedMessage.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation

/// A message on the price-feed WebSocket. On the wire it is a JSON envelope with a type
/// discriminator and a payload, e.g. `{"type":"prices","payload":[{"symbol":"AAPL",…}]}`.
nonisolated enum FeedMessage: Equatable, Sendable {
    case prices([PriceUpdate])
    /// A message type this app version doesn't know. Decoded rather than rejected, so a server
    /// that adds new message types doesn't break older apps; the feed ignores it.
    case unknown(type: String)
}

nonisolated extension FeedMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private static let pricesType = "prices"

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case Self.pricesType:
            self = .prices(try container.decode([PriceUpdate].self, forKey: .payload))
        default:
            self = .unknown(type: type)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .prices(let updates):
            try container.encode(Self.pricesType, forKey: .type)
            try container.encode(updates, forKey: .payload)
        case .unknown(let type):
            try container.encode(type, forKey: .type)
        }
    }
}

/// The single place that fixes the feed's message format: JSON (UTF-8 bytes) with ISO 8601 dates.
/// Framing is the connection's job; it sends these bytes as WebSocket text frames.
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

    func encode(_ message: FeedMessage) throws -> Data {
        try encoder.encode(message)
    }

    func decode(_ data: Data) throws -> FeedMessage {
        try decoder.decode(FeedMessage.self, from: data)
    }
}
