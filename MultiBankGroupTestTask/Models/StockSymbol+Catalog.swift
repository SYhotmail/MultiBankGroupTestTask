//
//  StockSymbol+Catalog.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

extension StockSymbol {
    /// The 25 symbols tracked by the app. Summaries are localized; tickers and company names are not.
    static let catalog: [StockSymbol] = [
        StockSymbol(ticker: "AAPL", name: "Apple Inc.", summary: String(localized: "Designs and sells iPhone, Mac, iPad, wearables and a growing portfolio of services such as the App Store, iCloud and Apple Music."), referencePrice: 228.50),
        StockSymbol(ticker: "MSFT", name: "Microsoft Corporation", summary: String(localized: "Develops Windows, Office and the Azure cloud platform, and owns LinkedIn, GitHub and Xbox."), referencePrice: 415.20),
        StockSymbol(ticker: "GOOG", name: "Alphabet Inc.", summary: String(localized: "Parent company of Google, operating Search, YouTube, Android, Google Cloud and the Waymo autonomous driving unit."), referencePrice: 172.10),
        StockSymbol(ticker: "AMZN", name: "Amazon.com, Inc.", summary: String(localized: "Runs the world's largest online marketplace and Amazon Web Services, the leading cloud infrastructure provider."), referencePrice: 186.40),
        StockSymbol(ticker: "NVDA", name: "NVIDIA Corporation", summary: String(localized: "Designs GPUs and accelerated computing platforms that power gaming, data centers and AI workloads."), referencePrice: 135.60),
        StockSymbol(ticker: "TSLA", name: "Tesla, Inc.", summary: String(localized: "Manufactures electric vehicles, battery energy storage systems and solar products."), referencePrice: 248.90),
        StockSymbol(ticker: "META", name: "Meta Platforms, Inc.", summary: String(localized: "Operates Facebook, Instagram, WhatsApp and Messenger, and invests in virtual and augmented reality."), referencePrice: 563.30),
        StockSymbol(ticker: "NFLX", name: "Netflix, Inc.", summary: String(localized: "Global subscription streaming service for films, series and games."), referencePrice: 702.80),
        StockSymbol(ticker: "AMD", name: "Advanced Micro Devices, Inc.", summary: String(localized: "Designs CPUs, GPUs and adaptive chips for PCs, consoles and data centers."), referencePrice: 158.70),
        StockSymbol(ticker: "INTC", name: "Intel Corporation", summary: String(localized: "Designs and manufactures processors and offers foundry services for third-party chip designers."), referencePrice: 22.40),
        StockSymbol(ticker: "ORCL", name: "Oracle Corporation", summary: String(localized: "Provides database software, enterprise applications and Oracle Cloud Infrastructure."), referencePrice: 168.90),
        StockSymbol(ticker: "CRM", name: "Salesforce, Inc.", summary: String(localized: "Leading provider of cloud-based customer relationship management software."), referencePrice: 289.10),
        StockSymbol(ticker: "ADBE", name: "Adobe Inc.", summary: String(localized: "Makes creative and document software including Photoshop, Premiere Pro and Acrobat."), referencePrice: 512.60),
        StockSymbol(ticker: "IBM", name: "International Business Machines", summary: String(localized: "Provides hybrid cloud, consulting, AI and mainframe solutions to enterprises."), referencePrice: 231.20),
        StockSymbol(ticker: "QCOM", name: "Qualcomm Incorporated", summary: String(localized: "Designs wireless and mobile chipsets and licenses foundational cellular technology."), referencePrice: 167.30),
        StockSymbol(ticker: "AVGO", name: "Broadcom Inc.", summary: String(localized: "Designs semiconductors for networking and storage, and sells infrastructure software."), referencePrice: 171.50),
        StockSymbol(ticker: "PYPL", name: "PayPal Holdings, Inc.", summary: String(localized: "Operates digital payment platforms including PayPal and Venmo."), referencePrice: 79.80),
        StockSymbol(ticker: "UBER", name: "Uber Technologies, Inc.", summary: String(localized: "Runs ride-hailing, food delivery and freight logistics marketplaces."), referencePrice: 74.60),
        StockSymbol(ticker: "SHOP", name: "Shopify Inc.", summary: String(localized: "Provides commerce software that lets merchants run online and in-store businesses."), referencePrice: 82.30),
        StockSymbol(ticker: "DIS", name: "The Walt Disney Company", summary: String(localized: "Entertainment company spanning studios, theme parks, ESPN and the Disney+ streaming service."), referencePrice: 96.10),
        StockSymbol(ticker: "JPM", name: "JPMorgan Chase & Co.", summary: String(localized: "The largest U.S. bank, offering consumer banking, investment banking and asset management."), referencePrice: 221.70),
        StockSymbol(ticker: "V", name: "Visa Inc.", summary: String(localized: "Operates one of the world's largest electronic payment networks."), referencePrice: 289.40),
        StockSymbol(ticker: "MA", name: "Mastercard Incorporated", summary: String(localized: "Global payments technology company connecting consumers, merchants and banks."), referencePrice: 512.30),
        StockSymbol(ticker: "KO", name: "The Coca-Cola Company", summary: String(localized: "Produces and markets beverage brands sold in more than 200 countries."), referencePrice: 69.80),
        StockSymbol(ticker: "WMT", name: "Walmart Inc.", summary: String(localized: "Operates retail stores, warehouse clubs and e-commerce businesses worldwide."), referencePrice: 81.20),
    ]
}
