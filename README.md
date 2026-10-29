# Real-Time Stock Price Tracker

An iOS app that shows live price updates for 25 stock symbols. Prices travel through a WebSocket echo
server (`wss://ws.postman-echo.com/raw`): the app
generates a random price update, sends it, and displays what the server echoes back.

Built with SwiftUI, Swift Concurrency (Swift 6 language mode, complete data-race safety) and the Observation framework, using the MVVM architecture. No third-party dependencies.

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

- Xcode 27.1 or later (Swift 6.4 toolchain; the project builds in the Swift 6 language mode)
- iOS 18.7 or later (iPhone and iPad). On iOS 26 and later the toolbar uses Liquid Glass; earlier versions get the standard toolbar.

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

The app follows **MVVM** (Model–View–ViewModel):

```
 Views (SwiftUI)                 ViewModels (@Observable)                 Model
 ───────────────                 ────────────────────────                 ─────
 StockSymbolsNavigationStackView ─▶ StockSymbolsNavigationViewModel ─┐
 StockSymbolsListView ───────────▶ StockSymbolsListViewModel ────────┼──▶ StockMarketModel ──▶ PriceFeed ──▶ WebSocketConnection
 StockSymbolDetailView ──────────▶ StockSymbolDetailViewModel ───────┘          │
                                                                                └──────────▶ SymbolsRepository
```

### Model

`StockMarketModel` is the single shared, `@Observable` source of live data: `symbols`, `quotes`, `connectionState`, `isLoadingSymbols` and `issue` (`symbolsUnavailable` / `connectionLost`). It owns the feed and the repository and exposes domain operations — `loadSymbols()`, `refresh()`, `toggleFeed()`, `reconnectFeed()`, `clearIssue()`, lifecycle hooks and `observeFeed()`. It knows nothing about presentation: no sorting, no alert wording, no formatting.

Below it sit the services:

| Type | Responsibility |
|---|---|
| `WebSocketPriceFeed` (`PriceFeed`, actor) | Session lifecycle: start/stop, suspend/resume, reconnect with backoff, echo timeout. Publishes a single `AsyncStream<PriceFeedEvent>`. |
| `PriceUpdateGenerator` | Seedable random walk (±2% per tick, rounded to cents) for a random subset of tracked symbols. |
| `WebSocketConnection` | Thin protocol over `URLSessionWebSocketTask`; swapped for an in-memory echo in tests. |
| `SymbolsRepository` (`Sendable`) | Supplies the symbol list. `BundledSymbolsRepository` (actor) serves the built-in catalog; a network-backed implementation can replace it without touching the UI. |

### ViewModels

One per screen, each adapting the shared model for its view:

| ViewModel | Exposes | Actions |
|---|---|---|
| `StockSymbolsNavigationViewModel` | `listViewModel`, `alert`; builds detail view models | `dismissAlert()`, `retry(_:)` — reload symbols or reconnect |
| `StockSymbolsListViewModel` | `sortOrder` (screen state), sorted `rows`, `connectionState`, `showsLoadingIndicator` | `toggleFeed()`, `refresh()`, `loadIfNeeded()` |
| `StockSymbolDetailViewModel` | `symbol`, live `quote`, `connectionState` | `toggleFeed()` |

View models hold no copies of model data: their properties are computed from `StockMarketModel`, so Observation tracks exactly the model fields a view reads, and both screens update in real time from the same source.

### Views

Views only render what their view model exposes and forward user actions to it. Reusable pieces (`FeedToolbar`, `ConnectionStatusView`, `PriceText`, `PriceChangeIndicator`) take plain values and closures, with no dependency on a view model.

### Composition root

`MultiBankGroupTestTaskApp` builds the model with its concrete services, creates the root view model, starts `observeFeed()` and forwards scene-phase changes to the model. Dependencies are passed through initializers rather than the SwiftUI environment, so each view model's inputs are explicit.

### Key decisions

- **Shared model, per-screen view models.** Live data must stay identical across screens, so it lives once in the model; what differs per screen (sort order, rows, alert mapping) lives in that screen's view model.
- **Computed view model properties.** No state is copied into view models, so there is nothing to keep in sync and nothing to go stale.
- **Render scope.** List rows live in a child view so per-tick updates don't rebuild the toolbar (which would close an open sort menu).
- **Protocols only at the I/O seams** (`WebSocketConnection`, `PriceFeed`, `SymbolsRepository`), where tests need to substitute real network and data access.
- **Concurrency: UI on the main actor, everything else off it.** The project uses the Swift 6 language mode, so data-race safety is checked at compile time. There is no default actor isolation: only UI-facing types are `@MainActor` — views, view models and `StockMarketModel`, which SwiftUI observes. Services are actors (`WebSocketPriceFeed`, `BundledSymbolsRepository`), so the WebSocket session, price generation and JSON coding run on their own executors, never the main thread. Everything that crosses between them is `Sendable`: value types (`StockSymbol`, `StockQuote`, `PriceUpdate`, `PriceFeedEvent`, `PriceUpdateGenerator`, `ReconnectPolicy`) and the `WebSocketConnection` transport. The UI talks to services with `await`, and feed events reach the main actor through an `AsyncStream`.
- **User intent vs. connection state.** The feed remembers whether the user wants it running separately from whether it's connected, so backgrounding, outages and retries never override an explicit Stop.
- **Trust boundary on the echo.** Echoed messages that fail to decode are dropped; updates for unknown tickers are ignored; duplicate tickers from the repository are de-duplicated.
- **Price change** is the change since the symbol's previous update; the indicator and the Price Change sort both use it.

## Project structure

```
MultiBankGroupTestTask/
├── MultiBankGroupTestTaskApp.swift      # Composition root
├── Models/                              # StockMarketModel, StockSymbol (+ catalog), StockQuote, PriceUpdate, ConnectionState
├── Services/
│   ├── Network/WebSocketConnection.swift
│   ├── PriceFeed/                       # PriceFeed, WebSocketPriceFeed, ReconnectPolicy, PriceUpdateGenerator
│   └── Symbols/SymbolsRepository.swift
├── Screens/
│   ├── StockSymbolsNavigation/          # Root view + view model: NavigationStack, alerts
│   ├── StockSymbolsList/                # List view + view model
│   ├── StockSymbolDetail/               # Detail view + view model
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
- **Race-free** — the suite also passes under Thread Sanitizer (`xcodebuild test … -enableThreadSanitizer YES`); test doubles are actors or `Mutex`-protected, so they're safe under the same rules as the app.

| Suite | Goal |
|---|---|
| `PriceUpdateGeneratorTests` | Reproducible sequences; distinct, known symbols per batch; prices positive, rounded to cents and within the configured change; symbol re-tracking. |
| `WebSocketPriceFeedTests` | Connect → echo → publish; stop/restart; retry until connected; dropped socket and silent-server reconnect; stop during backoff; suspend/resume; one `connectionLost` per outage; immediate reconnect; empty symbol list. |
| `ReconnectPolicyTests` | Exponential growth, cap and jitter scaling. |
| `StockMarketModelTests` | Price/change math; unknown symbols ignored; Start/Stop intents; lifecycle forwarding; feed events applied in order; symbol (re)loading, tracking and de-duplication; issue raising, precedence and clearing; refresh. |
| `StockSymbolsListViewModelTests` | Both sort orders with tie-break; rows carry live quotes; load-once; refresh; toggle and connection state through the model. |
| `StockSymbolDetailViewModelTests` | Quote follows live updates; toggle stops a running feed. |
| `StockSymbolsNavigationViewModelTests` | Alert mirrors the model issue; dismiss; retry reloads or reconnects; detail and list view models share live data. |
| `LocalizationTests` | Every UI string and symbol description has a German and Arabic entry, so untranslated text can't ship silently. |

## Source control

- `main` is the stable branch: it always builds and passes the tests.
- Work happens on feature branches merged into `main` with a merge commit (`--no-ff`), so each feature's history stays grouped and can be reverted as one unit. The implementation was built on `NetworkLayer`, moved to Redux on `Redux` and to MVVM on `MVVM`; the app icon came from `AppIcon`, and the Swift 6 migration and iOS 18.7 support from `Swift6`.
- Small, single-purpose commits with descriptive messages: the price feed and models, the screens and store, tests, UI refinements, reconnect and background handling, localization, pull-to-refresh and error alerts, and this README.
- Generated and per-user files (`xcuserdata/`, `DerivedData/`, `build/`, `.DS_Store`) are excluded via `.gitignore`.

## Known limitations

- The symbol list is bundled; there is no remote symbols API yet (`SymbolsRepository` is the extension point).
- Prices are simulated — the echo server returns exactly what the app sends.
- No `NWPathMonitor`: after the network returns, reconnection happens on the next backoff attempt (≤ 30 s) or via pull-to-refresh.
- Translations were not reviewed by native speakers.
