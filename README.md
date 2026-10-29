# Real-Time Stock Price Tracker

An iOS app that shows live price updates for 25 stock symbols. Prices travel through a WebSocket echo
server (`wss://ws.postman-echo.com/raw`): the app
generates a random price update, sends it, and displays what the server echoes back.

Built with SwiftUI, Swift Concurrency and the Observation framework, using a hand-rolled Redux architecture. No third-party dependencies.

## Features

**Symbols list**
- 25 symbols with ticker, company name, current price and a price-change indicator (▲ / ▼ / —, colored, signed amount).
- Sort by **Price** or **Price Change** from the toolbar menu (highest first).
- Connection status indicator (Connected / Connecting / Disconnected) and a **Start / Stop** button that controls the feed.
- Pull-to-refresh reloads the symbol list and reconnects a running feed immediately.

**Symbol details**
- Ticker as the title, company name, live price with the same indicator as the list, and a description.
- Shares the list's live data, so prices update in real time on both screens.

**Resilience**
- Automatic reconnect with exponential backoff and jitter (1 s → 30 s) after a failed connect, a dropped socket or an echo that doesn't arrive within 10 s.
- Pauses in the background (iOS doesn't keep plain sockets alive there) and resumes on return if the feed was running.
- Error dialog with **Retry** / **OK** for a failed symbol load and for a lost connection — once per outage, not on every retry.

**Localization**
- English, German and Arabic (including right-to-left layout) via a String Catalog.
- Prices and changes follow the user's locale formatting; prices stay in USD, the trading currency.

## Requirements

- Xcode 27.1 or later
- iOS 27.0 or later (iPhone and iPad)

## Getting started

Open `MultiBankGroupTestTask.xcodeproj`, select the **MultiBankGroupTestTask** scheme and run.
Tap **Start** (▶) to connect the feed.

Run the unit tests from the command line:

```bash
xcodebuild test \
  -project MultiBankGroupTestTask.xcodeproj \
  -scheme MultiBankGroupTestTask \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:MultiBankGroupTestTaskTests
```

## Architecture

The app follows **Redux**: one immutable `AppState`, changed only by a pure `AppReducer` in response to an `AppAction`. Side effects are returned by the reducer as `AppEffect` values and performed by the `AppStore`, which turns their results back into actions.

```
          ┌──────────── send(AppAction) ◀───────────────┐
          ▼                                             │
     AppStore ──▶ AppReducer.reduce(&state, action)     │
          │            │ returns [AppEffect]            │
          │            ▼                                │
          │      perform effects ──▶ PriceFeed ─── PriceFeedEvent ──▶ .feed(event)
          │                     └──▶ SymbolsRepository ── result ──▶ .symbolsLoaded / .symbolsLoadFailed
          ▼
  publishes state fields ──▶ SwiftUI views ── user intents ──▶ send(action)
```

### State

`AppState` is a value type and the single source of truth:

| Field | Meaning |
|---|---|
| `symbols` | Tracked symbols, in repository order. |
| `quotes` | Current price and change per ticker. |
| `connectionState` | `disconnected`, `connecting` or `connected`. |
| `isLoadingSymbols` | A symbol fetch is in flight. |
| `alert` | `symbolsUnavailable` or `connectionLost`, if one should be shown. |
| `sortOrder` | `price` or `priceChange`. |

Derived values (`sortedSymbols`, `quote(for:)`, `isFeedRunning`) are computed from these fields, so they can't drift out of sync.

### Actions

| Group | Actions |
|---|---|
| User intents | `toggleFeedTapped`, `loadSymbols`, `refreshRequested`, `sortOrderChanged`, `alertDismissed`, `alertRetryTapped` |
| App lifecycle | `appEnteredBackground`, `appBecameActive` |
| Effect results | `symbolsLoaded`, `symbolsLoadFailed`, `feed(PriceFeedEvent)` — `connectionChanged`, `priceUpdates`, `connectionLost` |

### Reducer

`AppReducer.reduce(_ state: inout AppState, _ action: AppAction) -> [AppEffect]` is the only code that changes state. It is pure: no I/O, no clocks, no randomness — the same input always gives the same output. For example:

- `toggleFeedTapped` → `[.startFeed]` or `[.stopFeed]` depending on `connectionState`.
- `refreshRequested` → sets `isLoadingSymbols`, returns `[.reconnectFeed, .fetchSymbols]`.
- `symbolsLoaded` → de-duplicates tickers, keeps quotes of symbols that remain, returns `[.trackSymbols]`.
- `feed(.priceUpdates)` → computes each new quote and its change; unknown tickers are ignored.
- `feed(.connectionLost)` → raises an alert unless one is already showing.

### Effects and store

`AppEffect` lists every side effect: `startFeed`, `stopFeed`, `suspendFeed`, `resumeFeed`, `reconnectFeed`, `trackSymbols`, `fetchSymbols`. `AppStore.send(_:)` reduces the action, commits the new state, then performs the effects: feed commands immediately, the symbol fetch asynchronously. It returns a `Task`, so pull-to-refresh can await the reload. `observeFeed()` turns the feed's event stream into `.feed(...)` actions.

The store publishes each state field as its own observable property and writes back only fields that changed. A view therefore re-renders only when what it reads changes — a price tick doesn't rebuild the toolbar (which would close an open sort menu).

### Services

| Layer | Type | Responsibility |
|---|---|---|
| Composition root | `MultiBankGroupTestTaskApp` | Wires concrete services, sends lifecycle actions, injects the store into the environment. |
| Feed | `WebSocketPriceFeed` (`PriceFeed`) | Session lifecycle: start/stop, suspend/resume, reconnect with backoff, echo timeout. Publishes a single `AsyncStream<PriceFeedEvent>`. |
| Generation | `PriceUpdateGenerator` | Seedable random walk (±2% per tick, rounded to cents) for a random subset of tracked symbols. |
| Transport | `WebSocketConnection` | Thin protocol over `URLSessionWebSocketTask`; swapped for an in-memory echo in tests. |
| Data | `SymbolsRepository` | Supplies the symbol list. `BundledSymbolsRepository` serves the built-in catalog; a network-backed implementation can replace it without touching the UI. |

### Key decisions

- **Hand-rolled Redux instead of a framework.** The app has one feature and a handful of actions; under 300 lines of store, reducer and types (including comments) cover it without a dependency such as The Composable Architecture.
- **Effects as data.** Because the reducer returns effects instead of running them, tests assert exactly which side effects an action causes without a network or a fake.
- **Long-running effect.** The WebSocket session lives in `WebSocketPriceFeed`; the reducer only commands it, and its events come back as actions.
- **Protocols only at the I/O seams** (`WebSocketConnection`, `PriceFeed`, `SymbolsRepository`), where tests need to substitute real network and data access.
- **Main-actor by default.** The app target uses default `MainActor` isolation; I/O is `async`. State, actions and effects are `nonisolated` and `Sendable` values.
- **User intent vs. connection state.** The feed remembers whether the user wants it running separately from whether it's connected, so backgrounding, outages and retries never override an explicit Stop.
- **Trust boundary on the echo.** Echoed messages that fail to decode are dropped; updates for unknown tickers are ignored; duplicate tickers from the repository are de-duplicated.
- **Price change** is the change since the symbol's previous update; the indicator and the Price Change sort both use it.

## Project structure

```
MultiBankGroupTestTask/
├── MultiBankGroupTestTaskApp.swift      # Composition root
├── Models/                              # StockSymbol (+ catalog), StockQuote, PriceUpdate, ConnectionState
├── Services/
│   ├── Network/WebSocketConnection.swift
│   ├── PriceFeed/                       # PriceFeed, WebSocketPriceFeed, ReconnectPolicy, PriceUpdateGenerator
│   └── Symbols/SymbolsRepository.swift
├── Store/                               # AppState, AppAction + AppEffect, AppReducer, AppStore
├── Screens/
│   ├── StockSymbolsNavigation/          # NavigationStack + alert presentation
│   ├── StockSymbolsList/
│   ├── StockSymbolDetail/
│   └── Components/                      # FeedToolbar, ConnectionStatusView, PriceText, PriceChangeIndicator
└── Localizable.xcstrings                # en (source), de, ar
MultiBankGroupTestTaskTests/
├── Support/TestDoubles.swift            # Seeded RNG, in-memory echo socket, fake feed and repository
└── *Tests.swift
```

## Testing strategy

Unit tests use **Swift Testing** and are designed to run unattended on CI:

- **Deterministic** — random prices come from a seeded generator (SplitMix64); time-based behavior uses millisecond intervals injected through initializers.
- **Offline** — the WebSocket is replaced by an in-memory echo connection that can fail to connect, drop, go silent or return malformed data.
- **Bounded** — the feed suite has a time limit, so a regression that hangs fails instead of stalling the pipeline.

| Suite | Goal |
|---|---|
| `PriceUpdateGeneratorTests` | Reproducible sequences; distinct, known symbols per batch; prices positive, rounded to cents and within the configured change; symbol re-tracking. |
| `WebSocketPriceFeedTests` | Connect → echo → publish; stop/restart; retry until connected; dropped socket and silent-server reconnect; stop during backoff; suspend/resume; one `connectionLost` per outage; immediate reconnect; empty symbol list. |
| `ReconnectPolicyTests` | Exponential growth, cap and jitter scaling. |
| `AppReducerTests` | Pure state transitions and requested effects for every action: feed control, lifecycle, symbol loading and de-duplication, price/change math, unknown tickers, both sort orders, alert raising, precedence, dismissal and retry. |
| `AppStoreTests` | The store performs effects against the feed and repository, feeds results back as actions, updates state synchronously and lets pull-to-refresh await the reload. |
| `LocalizationTests` | Every UI string and symbol description has a German and Arabic entry, so untranslated text can't ship silently. |

## Source control

- `main` is the stable branch: it always builds and passes the tests.
- Work happens on feature branches merged into `main` with a merge commit (`--no-ff`), so each feature's history stays grouped and can be reverted as one unit. The implementation was built on `NetworkLayer`; the move to Redux was made on `Redux`.
- Small, single-purpose commits with descriptive messages: the price feed and models, the screens and store, tests, UI refinements, reconnect and background handling, localization, pull-to-refresh and error alerts, and this README.
- Generated and per-user files (`xcuserdata/`, `DerivedData/`, `build/`, `.DS_Store`) are excluded via `.gitignore`.

## Known limitations

- The symbol list is bundled; there is no remote symbols API yet (`SymbolsRepository` is the extension point).
- Prices are simulated — the echo server returns exactly what the app sends.
- No `NWPathMonitor`: after the network returns, reconnection happens on the next backoff attempt (≤ 30 s) or via pull-to-refresh.
- Translations were not reviewed by native speakers.
