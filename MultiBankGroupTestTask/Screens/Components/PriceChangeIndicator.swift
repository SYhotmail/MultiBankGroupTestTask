//
//  PriceChangeIndicator.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

/// Arrow and signed amount showing how the price moved on the last update.
struct PriceChangeIndicator: View {
    let quote: StockQuote

    var body: some View {
        Label {
            Text(quote.change, format: .number.precision(.fractionLength(2)).sign(strategy: .always(includingZero: false)))
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: quote.change).doubleValue))
        } icon: {
            Image(systemName: quote.direction.systemImage)
        }
        .monospacedDigit()
        .foregroundStyle(quote.direction.color)
        .animation(.default, value: quote)
        .accessibilityLabel(quote.direction.accessibilityLabel)
        .accessibilityValue(Text(quote.change, format: .number.precision(.fractionLength(2))))
    }
}

private extension PriceDirection {
    var systemImage: String {
        switch self {
        case .up: "arrowtriangle.up.fill"
        case .down: "arrowtriangle.down.fill"
        case .unchanged: "minus"
        }
    }

    var color: Color {
        switch self {
        case .up: .green
        case .down: .red
        case .unchanged: .secondary
        }
    }

    var accessibilityLabel: Text {
        switch self {
        case .up: Text("Price up")
        case .down: Text("Price down")
        case .unchanged: Text("Price unchanged")
        }
    }
}

#Preview {
    VStack {
        PriceChangeIndicator(quote: StockQuote(price: 10, change: 1.25))
        PriceChangeIndicator(quote: StockQuote(price: 10, change: -0.5))
        PriceChangeIndicator(quote: StockQuote(price: 10))
    }
}
