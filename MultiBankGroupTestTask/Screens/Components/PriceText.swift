//
//  PriceText.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

/// Locale-aware USD price that animates digit changes.
struct PriceText: View {
    let price: Decimal

    var body: some View {
        Text(price, format: .currency(code: "USD"))
            .monospacedDigit()
            .contentTransition(.numericText(value: NSDecimalNumber(decimal: price).doubleValue))
            .animation(.default, value: price)
    }
}
