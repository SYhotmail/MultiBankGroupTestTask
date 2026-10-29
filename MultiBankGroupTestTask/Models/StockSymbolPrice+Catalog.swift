//
//  StockSymbolPrice+Catalog.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

nonisolated extension StockSymbolPrice {
    /// When the bundled prices were taken: the close of 28 Oct 2026 (16:00 New York).
    static let catalogDate = Date(timeIntervalSince1970: 1_793_217_600)

    /// The 25 symbols tracked by the app with their prices as of `catalogDate`.
    /// Summaries are localized; tickers and company names are not.
    static let catalog: [StockSymbolPrice] = [
        StockSymbolPrice(symbol: StockSymbol(ticker: "AAPL", name: "Apple Inc.", summary: String(localized: "Designs and sells iPhone, Mac, iPad, wearables and a growing portfolio of services such as the App Store, iCloud and Apple Music.")), price: 228.50, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "MSFT", name: "Microsoft Corporation", summary: String(localized: "Develops Windows, Office and the Azure cloud platform, and owns LinkedIn, GitHub and Xbox.")), price: 415.20, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "GOOG", name: "Alphabet Inc.", summary: String(localized: "Parent company of Google, operating Search, YouTube, Android, Google Cloud and the Waymo autonomous driving unit.")), price: 172.10, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "AMZN", name: "Amazon.com, Inc.", summary: String(localized: "Runs the world's largest online marketplace and Amazon Web Services, the leading cloud infrastructure provider.")), price: 186.40, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "NVDA", name: "NVIDIA Corporation", summary: String(localized: "Designs GPUs and accelerated computing platforms that power gaming, data centers and AI workloads.")), price: 135.60, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "TSLA", name: "Tesla, Inc.", summary: String(localized: "Manufactures electric vehicles, battery energy storage systems and solar products.")), price: 248.90, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "META", name: "Meta Platforms, Inc.", summary: String(localized: "Operates Facebook, Instagram, WhatsApp and Messenger, and invests in virtual and augmented reality.")), price: 563.30, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "NFLX", name: "Netflix, Inc.", summary: String(localized: "Global subscription streaming service for films, series and games.")), price: 702.80, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "AMD", name: "Advanced Micro Devices, Inc.", summary: String(localized: "Designs CPUs, GPUs and adaptive chips for PCs, consoles and data centers.")), price: 158.70, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "INTC", name: "Intel Corporation", summary: String(localized: "Designs and manufactures processors and offers foundry services for third-party chip designers.")), price: 22.40, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "ORCL", name: "Oracle Corporation", summary: String(localized: "Provides database software, enterprise applications and Oracle Cloud Infrastructure.")), price: 168.90, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "CRM", name: "Salesforce, Inc.", summary: String(localized: "Leading provider of cloud-based customer relationship management software.")), price: 289.10, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "ADBE", name: "Adobe Inc.", summary: String(localized: "Makes creative and document software including Photoshop, Premiere Pro and Acrobat.")), price: 512.60, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "IBM", name: "International Business Machines", summary: String(localized: "Provides hybrid cloud, consulting, AI and mainframe solutions to enterprises.")), price: 231.20, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "QCOM", name: "Qualcomm Incorporated", summary: String(localized: "Designs wireless and mobile chipsets and licenses foundational cellular technology.")), price: 167.30, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "AVGO", name: "Broadcom Inc.", summary: String(localized: "Designs semiconductors for networking and storage, and sells infrastructure software.")), price: 171.50, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "PYPL", name: "PayPal Holdings, Inc.", summary: String(localized: "Operates digital payment platforms including PayPal and Venmo.")), price: 79.80, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "UBER", name: "Uber Technologies, Inc.", summary: String(localized: "Runs ride-hailing, food delivery and freight logistics marketplaces.")), price: 74.60, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "SHOP", name: "Shopify Inc.", summary: String(localized: "Provides commerce software that lets merchants run online and in-store businesses.")), price: 82.30, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "DIS", name: "The Walt Disney Company", summary: String(localized: "Entertainment company spanning studios, theme parks, ESPN and the Disney+ streaming service.")), price: 96.10, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "JPM", name: "JPMorgan Chase & Co.", summary: String(localized: "The largest U.S. bank, offering consumer banking, investment banking and asset management.")), price: 221.70, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "V", name: "Visa Inc.", summary: String(localized: "Operates one of the world's largest electronic payment networks.")), price: 289.40, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "MA", name: "Mastercard Incorporated", summary: String(localized: "Global payments technology company connecting consumers, merchants and banks.")), price: 512.30, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "KO", name: "The Coca-Cola Company", summary: String(localized: "Produces and markets beverage brands sold in more than 200 countries.")), price: 69.80, timestamp: catalogDate),
        StockSymbolPrice(symbol: StockSymbol(ticker: "WMT", name: "Walmart Inc.", summary: String(localized: "Operates retail stores, warehouse clubs and e-commerce businesses worldwide.")), price: 81.20, timestamp: catalogDate),
    ]
}
