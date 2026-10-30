# Real-Time Stock Price Tracker

An iOS app that shows live prices for 25 stock symbols. The app generates random price updates, sends
them to the WebSocket echo server `wss://ws.postman-echo.com/raw`, and displays what comes back.

SwiftUI, Swift 6 concurrency, the Observation framework and MVVM. No third-party dependencies.

Built with [Claude Code](https://claude.com/claude-code) as a pair programmer. Claude Code wrote much of the
code, tests and documentation; I directed the work, made the architecture, concurrency and naming decisions,
and reviewed and refactored the result.

## Features

- **List:** ticker, name, price and a change indicator (▲ / ▼). Sort by price or price change. Connection
  status and Start/Stop. Pull to refresh, and an empty screen when there's nothing to show.
- **Details:** live price, indicator and description. Pull to refresh; a symbol the backend deleted
  (`404`) closes and leaves the list.
- **Live everywhere:** both screens share the same prices. iPad shows them side by side.
- **Resilient:** reconnects with exponential backoff (1–30 s) and as soon as the network returns, times out
  a silent server after 10 s, pauses in the background, and shows an alert with Retry for failed loads and lost connections.
- **Localized:** English, German and Arabic, including right-to-left layout.

## Getting started

Requires Xcode 27.1 or later and iOS 18.7 or later (iPhone and iPad).

Open `MultiBankGroupTestTask.xcodeproj`, run the **MultiBankGroupTestTask** scheme and tap **Start**.

## Architecture

```
Views ──▶ ViewModels ──▶ StockSymbolsPriceListener ──▶ PriceFeedProvider (actor) ──▶ WebSocketConnection
                    └──▶ StockSymbolsProvider
```

- **`StockSymbolsNavigationViewModel`** creates everything, and owns the selection and the one alert.
- **`StockSymbolsListViewModel`** owns which symbols exist and their sorted rows.
- **`StockSymbolDetailViewModel`** refreshes one symbol and reaches the list only through closures.
- **`StockSymbolsPriceListener`** is the shared live state: connection status and quotes.
- **`WebSocketPriceFeedProvider`** is an actor that owns the socket, price generation, JSON coding and
  reconnects, so none of that runs on the main thread.
- **`StockSymbolsProvider`** stands in for a backend (`GET /symbols`, `GET /symbols/{id}`). The bundled
  implementation serves a built-in catalog.

Key decisions:

- **Concurrency:** the app target's default isolation is `MainActor`, so UI types need no annotation.
  Everything else opts out: plain data and stateless services are `nonisolated`, and services with state
  are actors.
- **Wire format:** a JSON array of `{symbol, price, timestamp}` sent as text frames, because the echo server
  closes the socket on binary frames. Anything that doesn't decode is dropped.
- **Stored rows:** the list re-sorts only when symbols, quotes or the sort order change.
- **User intent:** the feed tracks whether you want it running apart from whether it's connected, so
  backgrounding and outages never override an explicit Stop.

## Project structure

```
MultiBankGroupTestTask/
├── Models/            # Symbols, prices, quotes, errors
├── Services/
│   ├── Network/       # WebSocket connection, symbols provider
│   ├── PriceFeed/     # Feed provider, price listener, generator, codec
│   └── Simulation/    # Debug-only failure scenarios
├── Screens/           # Navigation, list and detail: views and view models
├── Views/             # Shared components
└── Extensions/
MultiBankGroupTestTaskTests/
TestPlans/             # Min and Max
```

## Tests

Swift Testing, deterministic and offline: a seeded random generator, an in-memory echo socket, and fake
feed and provider. They cover the wire format, reconnects, the price listener and every view model.

| Plan | Runs |
|---|---|
| `Min` (default) | Unit tests, in seconds |
| `Max` | Unit tests in random order, with Thread Sanitizer and code coverage |

```bash
xcodebuild test -scheme MultiBankGroupTestTask -testPlan Min \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

## Simulating failures

Debug builds can fake failures, to see alerts, retries and empty screens. In Xcode, open Edit Scheme > Run >
Arguments and tick one `-simulate` entry. None of this code is in Release builds.

| Argument | What happens |
|---|---|
| `symbolsLoadFails` | The first two loads fail, then loading works |
| `symbolsRefreshFails` | The list loads, then the first pull-to-refresh fails |
| `symbolsEmpty` | The first load returns no symbols |
| `symbolRefreshFails` | The first refresh on a symbol fails |
| `symbolDeleted` | Refreshing a symbol answers `404` and removes it |
| `connectionFails` | After Start, three connection attempts fail |
| `connectionDrops` | After Start, the first two connections drop |
| `serverSilent` | After Start, the first connection gets no echo and times out |

## Known limitations

- The symbols backend is simulated by a bundled provider.
- Prices are random; the echo server returns exactly what the app sends.
- There are no UI tests.
- Translations weren't reviewed by native speakers.
