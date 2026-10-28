//
//  ConnectionStatusView.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 28/10/2026.
//

import SwiftUI

struct ConnectionStatusView: View {
    let state: ConnectionState

    var body: some View {
        Label {
            Text(state.title)
        } icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(state.color)
                .imageScale(.small)
        }
        .labelStyle(.titleAndIcon)
        .font(.footnote)
        .accessibilityElement(children: .combine)
    }
}

private extension ConnectionState {
    var title: LocalizedStringKey {
        switch self {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Disconnected"
        }
    }

    var color: Color {
        switch self {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .red
        }
    }
}

#Preview {
    VStack {
        ConnectionStatusView(state: .connected)
        ConnectionStatusView(state: .connecting)
        ConnectionStatusView(state: .disconnected)
    }
}
