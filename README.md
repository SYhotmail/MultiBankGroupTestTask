# Real-Time Stock Price Tracker

An iOS app that shows live price updates for 25 stock symbols. Prices travel through a WebSocket echo
server (`wss://ws.postman-echo.com/raw`): the app
generates a random price update, sends it, and displays what the server echoes back.

Built with SwiftUI, Swift Concurrency and the Observation framework. No third-party dependencies.

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

```
SwiftUI views ──read──▶ StockPriceStore (@Observable, single source of truth)
                             │                    │
                   loads symbols from        consumes events from
                             ▼                    ▼
                    SymbolsRepository        PriceFeed ──▶ PriceUpdateGenerator
                                                 │
                                                 ▼
                                         WebSocketConnection ──▶ wss://ws.postman-echo.com/raw
```

| Layer | Type | Responsibility |
|---|---|---|
| Composition root | `MultiBankGroupTestTaskApp` | Wires concrete services, forwards scene-phase changes, injects the store into the environment. |
| State | `StockPriceStore` | Symbols, quotes, connection state, sort order and alerts. Applies feed events; exposes intents (toggle, refresh, retry). |
| Feed | `WebSocketPriceFeed` (`PriceFeed`) | Session lifecycle: start/stop, suspend/resume, reconnect with backoff, echo timeout. Publishes a single `AsyncStream<PriceFeedEvent>`. |
| Generation | `PriceUpdateGenerator` | Seedable random walk (±2% per tick, rounded to cents) for a random subset of tracked symbols. |
| Transport | `WebSocketConnection` | Thin protocol over `URLSessionWebSocketTask`; swapped for an in-memory echo in tests. |
| Data | `SymbolsRepository` | Supplies the symbol list. `BundledSymbolsRepository` serves the built-in catalog; a network-backed implementation can replace it without touching the UI. |

### Key decisions

- **One store, shared by every screen.** Both screens read the same `@Observable` store from the environment, so a price update re-renders wherever it is visible — no syncing between screens.
- **Protocols only at the I/O seams** (`WebSocketConnection`, `PriceFeed`, `SymbolsRepository`), where tests need to substitute real network and data access.
- **Main-actor by default.** The app target uses default `MainActor` isolation; I/O is `async`. Value types that cross isolation are `nonisolated` and `Sendable`.
- **User intent vs. connection state.** The feed remembers whether the user wants it running separately from whether it's connected, so backgrounding, outages and retries never override an explicit Stop.
- **Trust boundary on the echo.** Echoed messages that fail to decode are dropped; updates for unknown tickers are ignored; duplicate tickers from the repository are de-duplicated.
- **Price change** is the change since the symbol's previous update; the indicator and the Price Change sort both use it.
- **Render scope.** List rows live in a child view so per-tick updates don't rebuild the toolbar (which would dismiss an open sort menu).

## Project structure

```
MultiBankGroupTestTask/
├── MultiBankGroupTestTaskApp.swift      # Composition root
├── Models/                              # StockSymbol (+ catalog), StockQuote, PriceUpdate, ConnectionState
├── Services/
│   ├── Network/WebSocketConnection.swift
│   ├── PriceFeed/                       # PriceFeed, WebSocketPriceFeed, ReconnectPolicy, PriceUpdateGenerator
│   └── Symbols/SymbolsRepository.swift
├── Store/StockPriceStore.swift
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
| `StockPriceStoreTests` | Price/change math; unknown symbols ignored; both sort orders; Start/Stop intents; lifecycle forwarding; symbol (re)loading and de-duplication; alert raising, precedence and retry. |
| `LocalizationTests` | Every UI string and symbol description has a German and Arabic entry, so untranslated text can't ship silently. |

## Source control

- `main` holds the initial project; features are developed on a feature branch (`NetworkLayer`) and merged into `main` through a pull request.
- Small, single-purpose commits with descriptive messages (feature, UI, resilience, localization, tests).

## Known limitations

- The symbol list is bundled; there is no remote symbols API yet (`SymbolsRepository` is the extension point).
- Prices are simulated — the echo server returns exactly what the app sends.
- No `NWPathMonitor`: after the network returns, reconnection happens on the next backoff attempt (≤ 30 s) or via pull-to-refresh.
- Translations were not reviewed by native speakers.
