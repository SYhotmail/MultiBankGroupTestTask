//
//  StockSymbol+Catalog.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import Foundation

extension StockSymbol {
    /// The 25 symbols tracked by the app.
    static let catalog: [StockSymbol] = [
        StockSymbol(ticker: "AAPL", name: "Apple Inc.", summary: "Designs and sells iPhone, Mac, iPad, wearables and a growing portfolio of services such as the App Store, iCloud and Apple Music.", referencePrice: 228.50),
        StockSymbol(ticker: "MSFT", name: "Microsoft Corporation", summary: "Develops Windows, Office and the Azure cloud platform, and owns LinkedIn, GitHub and Xbox.", referencePrice: 415.20),
        StockSymbol(ticker: "GOOG", name: "Alphabet Inc.", summary: "Parent company of Google, operating Search, YouTube, Android, Google Cloud and the Waymo autonomous driving unit.", referencePrice: 172.10),
        StockSymbol(ticker: "AMZN", name: "Amazon.com, Inc.", summary: "Runs the world's largest online marketplace and Amazon Web Services, the leading cloud infrastructure provider.", referencePrice: 186.40),
        StockSymbol(ticker: "NVDA", name: "NVIDIA Corporation", summary: "Designs GPUs and accelerated computing platforms that power gaming, data centers and AI workloads.", referencePrice: 135.60),
        StockSymbol(ticker: "TSLA", name: "Tesla, Inc.", summary: "Manufactures electric vehicles, battery energy storage systems and solar products.", referencePrice: 248.90),
        StockSymbol(ticker: "META", name: "Meta Platforms, Inc.", summary: "Operates Facebook, Instagram, WhatsApp and Messenger, and invests in virtual and augmented reality.", referencePrice: 563.30),
        StockSymbol(ticker: "NFLX", name: "Netflix, Inc.", summary: "Global subscription streaming service for films, series and games.", referencePrice: 702.80),
        StockSymbol(ticker: "AMD", name: "Advanced Micro Devices, Inc.", summary: "Designs CPUs, GPUs and adaptive chips for PCs, consoles and data centers.", referencePrice: 158.70),
        StockSymbol(ticker: "INTC", name: "Intel Corporation", summary: "Designs and manufactures processors and offers foundry services for third-party chip designers.", referencePrice: 22.40),
        StockSymbol(ticker: "ORCL", name: "Oracle Corporation", summary: "Provides database software, enterprise applications and Oracle Cloud Infrastructure.", referencePrice: 168.90),
        StockSymbol(ticker: "CRM", name: "Salesforce, Inc.", summary: "Leading provider of cloud-based customer relationship management software.", referencePrice: 289.10),
        StockSymbol(ticker: "ADBE", name: "Adobe Inc.", summary: "Makes creative and document software including Photoshop, Premiere Pro and Acrobat.", referencePrice: 512.60),
        StockSymbol(ticker: "IBM", name: "International Business Machines", summary: "Provides hybrid cloud, consulting, AI and mainframe solutions to enterprises.", referencePrice: 231.20),
        StockSymbol(ticker: "QCOM", name: "Qualcomm Incorporated", summary: "Designs wireless and mobile chipsets and licenses foundational cellular technology.", referencePrice: 167.30),
        StockSymbol(ticker: "AVGO", name: "Broadcom Inc.", summary: "Designs semiconductors for networking and storage, and sells infrastructure software.", referencePrice: 171.50),
        StockSymbol(ticker: "PYPL", name: "PayPal Holdings, Inc.", summary: "Operates digital payment platforms including PayPal and Venmo.", referencePrice: 79.80),
        StockSymbol(ticker: "UBER", name: "Uber Technologies, Inc.", summary: "Runs ride-hailing, food delivery and freight logistics marketplaces.", referencePrice: 74.60),
        StockSymbol(ticker: "SHOP", name: "Shopify Inc.", summary: "Provides commerce software that lets merchants run online and in-store businesses.", referencePrice: 82.30),
        StockSymbol(ticker: "DIS", name: "The Walt Disney Company", summary: "Entertainment company spanning studios, theme parks, ESPN and the Disney+ streaming service.", referencePrice: 96.10),
        StockSymbol(ticker: "JPM", name: "JPMorgan Chase & Co.", summary: "The largest U.S. bank, offering consumer banking, investment banking and asset management.", referencePrice: 221.70),
        StockSymbol(ticker: "V", name: "Visa Inc.", summary: "Operates one of the world's largest electronic payment networks.", referencePrice: 289.40),
        StockSymbol(ticker: "MA", name: "Mastercard Incorporated", summary: "Global payments technology company connecting consumers, merchants and banks.", referencePrice: 512.30),
        StockSymbol(ticker: "KO", name: "The Coca-Cola Company", summary: "Produces and markets beverage brands sold in more than 200 countries.", referencePrice: 69.80),
        StockSymbol(ticker: "WMT", name: "Walmart Inc.", summary: "Operates retail stores, warehouse clubs and e-commerce businesses worldwide.", referencePrice: 81.20),
    ]
}
