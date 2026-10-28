//
//  SymbolsNavigationStackView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct StockSymbolsNavigationStackView: View {
    var body: some View {
        
        NavigationSplitView {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        } detail: {
            Text("Hello")
        }
    }
}

#Preview {
    StockSymbolsNavigationStackView()
}
