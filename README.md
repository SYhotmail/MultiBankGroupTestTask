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
- Pull-to-refresh re-fetches the symbol from the backend (`GET /symbols/{id}`): its details, and its price when the backend's is newer than the live one.
- If the symbol is deleted — the backend answers `404`, or a list reload no longer includes it — the selection clears: the detail closes on iPhone and shows a placeholder on iPad, and the symbol leaves the list.

**Navigation**
- `NavigationSplitView`: the list in the sidebar and the selected symbol in the detail column on iPad; it collapses to a push-style stack on iPhone. Side by side, the detail column leaves the Start/Stop control and status to the list's toolbar.

**Resilience**
- Automatic reconnect with exponential backoff and jitter (1 s → 30 s) after a failed connect, a dropped socket or an echo that doesn't arrive within 10 s.
- Pauses in the background (iOS doesn't keep plain sockets alive there) and resumes on return if the feed was running.
- Error dialog with **Retry** / **OK** for a failed symbol list load, a failed single-symbol refresh and a lost connection — once per outage, not on every retry.

**Localization**
- English, German and Arabic (including right-to-left layout) via a String Catalog.
- Prices and changes follow the user's locale formatting; prices stay in USD, the trading currency.

## Requirements

- Xcode 27.1 or later (Swift 6.4 toolchain; the project builds in the Swift 6 language mode)
- iOS 18.7 or later (iPhone and iPad). On iOS 26 and later the toolbar uses Liquid Glass; earlier versions get the standard toolbar.

## Getting started

Open `MultiBankGroupTestTask.xcodeproj`, select the **MultiBankGroupTestTask** scheme and run.
Tap **Start** (▶) to connect the feed.

The scheme has two test plans, in `TestPlans/`:

| Plan | Runs | Use it for |
|---|---|---|
| `Min` (default) | Unit tests | Every change and pull request: finishes in seconds |
| `Max` | Unit and UI tests, in random order, with Thread Sanitizer and code coverage | Before a merge or a release |

Run one from the command line:

```bash
xcodebuild test \
  -project MultiBankGroupTestTask.xcodeproj \
  -scheme MultiBankGroupTestTask \
  -testPlan Min \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

## Architecture

The app follows **MVVM** (Model–View–ViewModel):

```
 Views (SwiftUI)                   ViewModels (@Observable)                       Shared model / services
 ───────────────                   ────────────────────────                       ───────────────────────
 StockSymbolsNavigationView ──────▶ StockSymbolsNavigationViewModel (coordinator)
                                      │ creates, owns selection + alert
 StockSymbolsListView ────────────▶ StockSymbolsListViewModel ───── symbols ─────▶ StockSymbolsProvider
                                      │           └──────────── live quotes ──────▶ StockSymbolsPriceListener ──▶ PriceFeedProvider ──▶ WebSocketConnection
 StockSymbolDetailView ───────────▶ StockSymbolDetailViewModel ──── refresh ──────▶ StockSymbolsProvider
                                        (details via the list, quote via StockSymbolsPriceListener)
```

### Model

`StockSymbolsPriceListener` is only the **live connection**, the one piece of state every screen shares: the WebSocket feed's `connectionState` and the live `quotes` of the symbols it's told to track. It exposes `observeFeed()`, `track(_:)` / `untrack(ticker:)` (which symbols get prices) and `applyIfNewer(_:)` (a fresher price from the backend), and reports a lost connection through `onConnectionLost`. It doesn't control the feed (the view models do) and knows nothing about which symbols exist, loading, sorting or alerts.

Below it sit the services:

| Type | Responsibility |
|---|---|
| `WebSocketPriceFeedProvider` (`PriceFeedProvider`, actor) | Session lifecycle: start/stop, suspend/resume, reconnect with backoff, echo timeout. Publishes a single `AsyncStream<PriceFeedEvent>`. |
| `FeedMessageCodec` | The one place that fixes the message format: a JSON array of `PriceUpdate`s (`Codable`) as UTF-8 bytes (`Data`), ISO 8601 dates. The connection sends them as text frames (JSON is text, and the echo server closes the socket on binary frames) and accepts text or binary frames back. |
| `PriceUpdateGenerator` | Seedable random walk (±2% per tick, rounded to cents) for a random subset of tracked symbols. |
| `WebSocketConnection` | Thin protocol over `URLSessionWebSocketTask`; swapped for an in-memory echo in tests. |
| `StockSymbolsProvider` (`Sendable`) | The symbols backend API: `fetchStockSymbols()` (`GET /symbols`) and `fetchStockSymbol(id:)` (`GET /symbols/{id}`, throws `notFound`). `BundledStockSymbolsRepository` (stateless `Sendable` struct with `@concurrent` methods) serves the built-in catalog with simulated latency; a network-backed implementation can replace it without touching the UI. |

### ViewModels

Each screen's logic lives in its view model; the navigation view model coordinates them:

| ViewModel | Owns | Actions |
|---|---|---|
| `StockSymbolBaseViewModel` (shared base of the list and detail view models) | The `provider`, the `priceListener`, the `feed`, the `logger` and the `onError` callback; `connectionState`, `isFeedRunning` | `toggleFeed()` (Start/Stop), `reconnectFeed()`, `refresh()` (reconnects; subclasses then reload their own data) |
| `StockSymbolsNavigationViewModel` | Creates the `StockSymbolsPriceListener` and the list view model from a provider and a feed, builds detail view models; `selectedTicker` / `selectedSymbol` for the detail column (reads as `nil` once the symbol is deleted); the one `alert` (+ Debug description) that any of them reports — an unseen alert is never replaced | `dismissAlert()`, `retry(_:)` — reload the list, refresh the symbol or reconnect; `observeFeed()`, and the background/foreground hooks that suspend and resume the feed |
| `StockSymbolsListViewModel` | Which symbols exist (`GET /symbols`): `symbols`, `isLoading`, de-duplication, telling the price listener what to price; `sortOrder` and sorted `rows` with live quotes, rebuilt only when the symbols, quotes or sort order change | `loadIfNeeded()`, `load()`, `refresh()`; `replace(_:)` / `remove(ticker:)` for the detail screen; feed controls from `StockSymbolBaseViewModel` |
| `StockSymbolDetailViewModel` | One symbol (`GET /symbols/{id}`): its details from the list, its live `quote` from the price listener | `refresh()` — newer details into the list, a newer price into the price listener, a `404` removes the symbol, other failures are reported; feed controls from `StockSymbolBaseViewModel` |

Child view models report problems through `StockSymbolsErrorHandler` callbacks that capture the navigation view model weakly, so the ownership graph has no cycles (`MemoryLeakTests` guards this).

### Views

Views only render what their view model exposes and forward user actions to it. Reusable pieces (`FeedToolbar`, `ConnectionStatusView`, `PriceText`, `PriceChangeIndicator`) take plain values and closures, with no dependency on a view model.

### Composition root

`MultiBankGroupTestTaskApp` creates the root view model from the live services (`StockSymbolsNavigationViewModel.live`: bundled symbols, Postman echo feed) and holds only that view model: it starts `observeFeed()` and forwards scene-phase changes through it. The navigation view model builds the `StockSymbolsPriceListener` and the list view model from the provider and feed it's given, and passes them only to the view models it creates; nothing else sees the model. Previews use `StockSymbolsNavigationViewModel.preview` the same way. Dependencies are passed through initializers rather than the SwiftUI environment, so each view model's inputs are explicit.

### Key decisions

- **Shared live connection, per-screen logic.** Only the WebSocket connection and its live quotes are shared, so only they live in `StockSymbolsPriceListener`. The list owns which symbols exist, the detail screen owns single-symbol refreshes, and the navigation view model coordinates them and owns the alert.
- **One source of truth per fact.** Symbols live in the list view model, prices in the price listener; other view models read them through computed properties, so nothing is copied and nothing goes stale.
- **Render scope.** List rows live in a child view so per-tick updates don't rebuild the toolbar (which would close an open sort menu).
- **Protocols only at the I/O seams** (`WebSocketConnection`, `PriceFeedProvider`, `StockSymbolsProvider`), where tests need to substitute real network and data access.
- **Concurrency: UI on the main actor, everything else off it.** The project uses the Swift 6 language mode, so data-race safety is checked at compile time. The app target's default actor isolation is `MainActor`, so views, view models and `StockSymbolsPriceListener` (which SwiftUI observes) need no annotation, and everything else opts out explicitly: plain data and stateless services are `nonisolated`. Services that own mutable state are actors (`WebSocketPriceFeedProvider`), so the WebSocket session, price generation and JSON coding run on its executor, never the main thread. Stateless services are `Sendable` structs whose methods are `@concurrent` (`BundledStockSymbolsRepository`), so they too run off the main thread without an actor's isolation; one becomes an actor only when it gains state to protect. Everything that crosses between them is `Sendable`: value types (`StockSymbol`, `StockSymbolPrice`, `StockQuote`, `PriceUpdate`, `PriceFeedEvent`, `PriceUpdateGenerator`, `ReconnectPolicy`) and the `WebSocketConnection` transport. The UI talks to services with `await`, and feed events reach the main actor through an `AsyncStream`.
- **User intent vs. connection state.** The feed remembers whether the user wants it running separately from whether it's connected, so backgrounding, outages and retries never override an explicit Stop.
- **Wire format.** Every WebSocket message is a plain JSON array of price updates, e.g. `[{"symbol":"AAPL","price":229.1,"timestamp":"2027-01-15T08:00:00Z"}]`, encoded and decoded with `Codable` by `FeedMessageCodec`. The feed carries only prices, so there is no type envelope; anything that isn't a valid price array fails to decode and is dropped. `JSONEncoder`/`JSONDecoder` aren't `Sendable`, so the codec lives inside the feed actor. The codec works in bytes (`Data`); the connection owns framing and sends them as text frames after checking they're valid UTF-8, while accepting text or binary frames from the server.
- **Trust boundary on the echo.** Echoed messages that fail to decode are dropped; updates for unknown tickers are ignored; duplicate tickers from the provider are de-duplicated.
- **Identity apart from price.** `StockSymbol` is what a symbol is (ticker, name, description). `StockSymbolPrice` is a symbol's price at a point in time — the provider returns these (the bundled catalog is a snapshot as of 28 Oct 2026 close), the feed starts its random walk from them, and they are the quote shown until the first live update. `StockQuote` is the live price with its change and `updatedAt`.
- **Price change** is the change since the symbol's previous update; the indicator and the Price Change sort both use it.

## Project structure

```
MultiBankGroupTestTask/
├── MultiBankGroupTestTaskApp.swift      # Composition root
├── Extensions/                          # Logger+ViewModels: the OSLog logger the view models write to
├── Models/                              # StockSymbol, StockSymbolPrice, StockQuote, PriceUpdate, ConnectionState
├── Services/
│   ├── Network/
│   │   ├── WebSocketConnection.swift
│   │   └── Symbols/                     # StockSymbolsProvider, BundledStockSymbolsRepository, StockSymbolPrice catalog
│   └── PriceFeed/                       # PriceFeedProvider, WebSocketPriceFeedProvider, StockSymbolsPriceListener, ReconnectPolicy, PriceUpdateGenerator, FeedMessageCodec
├── ViewModels/                          # StockSymbolBaseViewModel: shared base with provider, price listener, feed, Start/Stop, refresh, error reporting
├── Screens/
│   ├── StockSymbolsNavigation/          # Root view + view model: NavigationSplitView, selection, alerts
│   ├── StockSymbolsList/                # List view + view model
│   ├── StockSymbolDetail/               # Detail view + view model
│   └── Components/                      # FeedToolbar, ConnectionStatusView, PriceText, PriceChangeIndicator
└── Localizable.xcstrings                # en (source), de, ar
TestPlans/                               # Min and Max
MultiBankGroupTestTaskTests/
├── Support/TestDoubles.swift            # Seeded RNG, in-memory echo socket, fake feed and provider
└── *Tests.swift
```

## Testing strategy

Unit tests use **Swift Testing** and are designed to run unattended on CI:

- **Deterministic** — random prices come from a seeded generator (SplitMix64); time-based behavior uses millisecond intervals injected through initializers.
- **Offline** — the WebSocket is replaced by an in-memory echo connection that can fail to connect, drop, go silent or return malformed data.
- **Bounded** — the feed suite has a time limit, so a regression that hangs fails instead of stalling the pipeline.
- **Race-free** — the suite also passes under Thread Sanitizer (the `Max` test plan); test doubles are actors or `Mutex`-protected, so they're safe under the same rules as the app.

| Suite | Goal |
|---|---|
| `WebSocketConnectionTests` | Text frames: valid UTF-8 becomes the frame text, invalid UTF-8 is refused, codec output is always a valid text frame. |
| `FeedMessageCodecTests` | Pins the wire format: plain array shape, ISO 8601 dates, round trip, decoding a server-written message, and rejection of anything else (objects, missing fields, non-ISO dates, non-JSON). |
| `PriceUpdateGeneratorTests` | Reproducible sequences; distinct, known symbols per batch; prices positive, rounded to cents and within the configured change; symbol re-tracking. |
| `WebSocketPriceFeedProviderTests` | Connect → echo → publish; stop/restart; retry until connected; dropped socket and silent-server reconnect; stop during backoff; suspend/resume; one `connectionLost` per outage; immediate reconnect; empty symbol list. |
| `ReconnectPolicyTests` | Exponential growth, cap and jitter scaling. |
| `StockSymbolsPriceListenerTests` | The live connection: tracking keeps live quotes, adds and drops symbols; untracking; price/change math; untracked symbols ignored; newer vs. older backend prices; connection state; connection-lost reports; feed events applied in order. |
| `StockSymbolsListViewModelTests` | Loading lists and prices symbols; both sort orders with tie-break; live rows; load-once; refresh reconnects and reloads; reload keeps live quotes; duplicate tickers; failed loads reported with the error; replace and remove; feed controls from `StockSymbolBaseViewModel` (Start/Stop for every connection state, reconnect). |
| `StockSymbolDetailViewModelTests` | Live quote; refresh updates details in the list; newer vs. older prices; mismatched responses ignored; `404` deletes the symbol without an alert; other failures reported; Start/Stop. |
| `StockSymbolsProviderTests` | The bundled provider behaves like the endpoints: list, fetch by id, `notFound` for unknown ids. |
| `StockSymbolsNavigationViewModelTests` | Driven only through the fake provider and feed (the model is internal). Selection shows the symbol and clears after a `404`, a list reload without it, or for an unknown ticker; alerts from the list, detail and connection, and an unseen one isn't replaced; dismiss; retry reloads the list, refreshes the symbol or reconnects; detail and list view models share live data. |
| `MemoryLeakTests` | No retain cycles: after the navigation view model has loaded symbols, opened a detail, toggled the feed and applied feed events, releasing it releases the list and detail view models and the model (checked through its feed, which only the model owns). |
| `LocalizationTests` | Every UI string and symbol description has a German and Arabic entry, so untranslated text can't ship silently. |

## Source control

- `main` is the stable branch: it always builds and passes the tests.
- Work happens on feature branches merged into `main` with a merge commit (`--no-ff`), so each feature's history stays grouped and can be reverted as one unit. The implementation was built on `NetworkLayer`, moved to Redux on `Redux` and to MVVM on `MVVM`; the app icon came from `AppIcon`, and the Swift 6 migration and iOS 18.7 support from `Swift6`.
- Small, single-purpose commits with descriptive messages: the price feed and models, the screens and store, tests, UI refinements, reconnect and background handling, localization, pull-to-refresh and error alerts, and this README.
- Generated and per-user files (`xcuserdata/`, `DerivedData/`, `build/`, `.DS_Store`) are excluded via `.gitignore`.

## Known limitations

- The symbols API is simulated by a bundled provider; there is no remote backend yet (`StockSymbolsProvider` is the extension point).
- When a single-symbol refresh brings a newer price, the quote updates but the simulated feed keeps walking from its own last price.
- Prices are simulated — the echo server returns exactly what the app sends.
- No `NWPathMonitor`: after the network returns, reconnection happens on the next backoff attempt (≤ 30 s) or via pull-to-refresh.
- Translations were not reviewed by native speakers.
