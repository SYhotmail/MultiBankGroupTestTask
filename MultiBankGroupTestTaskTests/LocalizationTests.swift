//
//  LocalizationTests.swift
//  MultiBankGroupTestTaskTests
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation
import Testing
@testable import MultiBankGroupTestTask

/// Guards against shipping untranslated text: every UI string and symbol summary must resolve
/// to a translation in each supported language.
struct LocalizationTests {
    static let languages = ["de", "ar"]

    /// Keep in sync with the string literals used by the screens.
    private static let uiKeys = [
        "Stocks", "Start", "Stop", "Sort", "Sort by", "Price", "Price Change",
        "Connected", "Connecting", "Disconnected",
        "Price up", "Price down", "Price unchanged", "About",
        "Couldn't Load Symbols", "Check your connection and try again.",
        "Connection Problem", "Live prices are unavailable. The app will keep trying to reconnect.",
        "Retry", "OK", "Updated %@",
    ]

    /// Returned by `localizedString` only when the key has no entry; a translation may equal its key (e.g. "OK").
    private static let missing = "<missing>"

    private func bundle(for language: String) throws -> Bundle {
        let appBundle = Bundle(for: StockMarketModel.self)
        let path = try #require(appBundle.path(forResource: language, ofType: "lproj"), "Missing \(language).lproj")
        return try #require(Bundle(path: path))
    }

    @Test(arguments: languages)
    func uiStringsAreTranslated(language: String) throws {
        let bundle = try bundle(for: language)
        for key in Self.uiKeys {
            #expect(bundle.localizedString(forKey: key, value: Self.missing, table: nil) != Self.missing, "\(key) in \(language)")
        }
    }

    @Test(arguments: languages)
    func symbolSummariesAreTranslated(language: String) throws {
        let bundle = try bundle(for: language)
        // Tests run in English, so `summary` holds the source-language key.
        for symbol in StockSymbol.catalog {
            #expect(bundle.localizedString(forKey: symbol.summary, value: Self.missing, table: nil) != Self.missing, "\(symbol.ticker) in \(language)")
        }
    }
}
