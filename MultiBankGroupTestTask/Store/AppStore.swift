//
//  AppStore.swift
//  MultiBankGroupTestTask
//
//  Created by Siarhei Yakushevich on 29/10/2026.
//

import Foundation
import Observation

/// Holds the `AppState`, feeds actions through `AppReducer` and performs the effects it returns.
///
/// Each state field is published as its own observable property, so a view re-renders only when
/// the fields it reads change. Observing the whole struct would rebuild every view, including the
/// toolbar and its open sort menu, on each price tick.
@Observable
final class AppStore {
    private(set) var symbols: [StockSymbol] = []
    private(set) var quotes: [String: StockQuote] = [:]
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var isLoadingSymbols = false
    private(set) var alert: AppState.Alert?
    private(set) var sortOrder: AppState.SortOrder = .price

    @ObservationIgnored private let repository: any SymbolsRepository
    @ObservationIgnored private let feed: any PriceFeed

    init(repository: any SymbolsRepository, feed: any PriceFeed) {
        self.repository = repository
        self.feed = feed
    }

    /// Snapshot of the current state; reading it observes every field.
    var state: AppState {
        AppState(
            symbols: symbols,
            quotes: quotes,
            connectionState: connectionState,
            isLoadingSymbols: isLoadingSymbols,
            alert: alert,
            sortOrder: sortOrder
        )
    }

    /// Reduces the action, then performs its effects. State is updated before this returns;
    /// await the returned task to wait for asynchronous effects (e.g. pull-to-refresh).
    @discardableResult
    func send(_ action: AppAction) -> Task<Void, Never> {
        var next = state
        let effects = AppReducer.reduce(&next, action)
        commit(next)
        let asyncWork = effects.compactMap(perform)
        return Task {
            for work in asyncWork {
                await work()
            }
        }
    }

    /// Turns feed events into actions until the feed's stream ends. Run once for the store's lifetime.
    func observeFeed() async {
        for await event in feed.events {
            send(.feed(event))
        }
    }

    /// Performs a synchronous effect immediately, or returns the asynchronous work to run.
    private func perform(_ effect: AppEffect) -> (() async -> Void)? {
        switch effect {
        case .startFeed: feed.start()
        case .stopFeed: feed.stop()
        case .suspendFeed: feed.suspend()
        case .resumeFeed: feed.resume()
        case .reconnectFeed: feed.reconnect()
        case .trackSymbols(let symbols): feed.track(symbols)
        case .fetchSymbols:
            return { [repository] in
                do {
                    await self.send(.symbolsLoaded(try await repository.fetchSymbols())).value
                } catch {
                    await self.send(.symbolsLoadFailed).value
                }
            }
        }
        return nil
    }

    /// Writes back only the fields that changed, so unrelated observers aren't invalidated.
    private func commit(_ new: AppState) {
        if symbols != new.symbols { symbols = new.symbols }
        if quotes != new.quotes { quotes = new.quotes }
        if connectionState != new.connectionState { connectionState = new.connectionState }
        if isLoadingSymbols != new.isLoadingSymbols { isLoadingSymbols = new.isLoadingSymbols }
        if alert != new.alert { alert = new.alert }
        if sortOrder != new.sortOrder { sortOrder = new.sortOrder }
    }
}
