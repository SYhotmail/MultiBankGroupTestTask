# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

iOS app (SwiftUI, Swift 6, Observation, MVVM, no third-party dependencies) showing live prices for 25
stock symbols. Random price updates are sent to the echo server `wss://ws.postman-echo.com/raw` and the
echoed values are displayed. See `README.md` for features and the full list of debug failure scenarios.

## Commands

Requires Xcode 27.1+, iOS 18.7+ deployment target. Pick an installed simulator with
`xcrun simctl list devices available` (the README's `iPhone 18 Pro` may not exist locally).

```bash
# Build
xcodebuild build -scheme MultiBankGroupTestTask -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Fast unit tests (default plan)
xcodebuild test -scheme MultiBankGroupTestTask -testPlan Min -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Random order + Thread Sanitizer + coverage
xcodebuild test -scheme MultiBankGroupTestTask -testPlan Max -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Single suite or test (Swift Testing identifiers: Target/SuiteType/testFunction())
xcodebuild test -scheme MultiBankGroupTestTask -testPlan Min -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:MultiBankGroupTestTaskTests/FeedMessageCodecTests
```

No linter is configured. Source folders are Xcode file-system-synchronized groups, so new files under
`MultiBankGroupTestTask/` or `MultiBankGroupTestTaskTests/` are picked up without editing `project.pbxproj`.

## Architecture

```
Views ──▶ ViewModels ──▶ StockSymbolsPriceListener ──▶ PriceFeedProvider (actor) ──▶ WebSocketConnection
                    └──▶ StockSymbolsProvider
```

- **Composition root:** `StockSymbolsNavigationViewModel.live` in `Screens/Root/MultiBankGroupTestTaskApp.swift`.
  The App drives `observeFeed()` / `observeNetwork()` via `.task` and forwards scene phase to
  `appDidEnterBackground()` / `appDidBecomeActive()`.
- **`StockSymbolsNavigationViewModel`** creates the other view models and owns selection and the single alert.
  **`StockSymbolsListViewModel`** owns which symbols exist and the stored sorted rows (re-sorted only when
  symbols, quotes or sort order change). **`StockSymbolDetailViewModel`** reaches the list only through
  closures (e.g. removing a symbol on a `404`).
- **`StockSymbolsPriceListener`** is the shared live state (connection status + quotes) used by both screens.
- **`WebSocketPriceFeedProvider`** (actor) owns the socket, price generation (`PriceUpdateGenerator`),
  JSON coding (`FeedMessageCodec`), reconnect with exponential backoff (1–30 s, immediate on network
  return) and the 2-minute silent-server timeout. Connects rely on `URLSession`'s own timeout.
- **`StockSymbolsProvider`** stands in for a backend (`GET /symbols`, `GET /symbols/{id}`);
  `BundledStockSymbolsRepository` serves a built-in catalog.
- The feed tracks *user intent* (wants running) separately from *connected*, so backgrounding and outages
  never override an explicit Stop.

## Conventions

- **Concurrency:** the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable
  concurrency, so UI types need no annotation. Non-UI code opts out explicitly: plain data and stateless
  services are `nonisolated`; stateful services are `actor`s. The test target does **not** default to
  MainActor — tests touching view models are annotated `@MainActor`.
- **Wire format:** JSON array of `{symbol, price, timestamp}` sent as **text** frames (the echo server
  closes the socket on binary frames). Undecodable messages are dropped.
- **Debug failure simulation:** `Services/Simulation/SimulatedFailure.swift` (`#if DEBUG` only) wraps real
  services at their protocol boundary, selected by launch argument `-simulate <case>` (listed, disabled, in
  the scheme's Run > Arguments). Adding a scenario means a new case here plus a scheme argument entry.
- **Logging:** view models take an injected `Logger` (`Logger.viewModels` in the app, `Logger.empty` in tests).
- **Localization:** `Localizable.xcstrings` with English, German and Arabic (RTL) — new user-facing strings
  need all three.

## Tests

Swift Testing, deterministic and offline. Shared doubles live in `MultiBankGroupTestTaskTests/Support/TestDoubles.swift`:
`SeededRandomNumberGenerator`, `EchoWebSocketConnection` (in-memory echo socket), `FakePriceFeed`,
`FakeStockSymbolsProvider`, `FakeNetworkMonitor`. Reuse these rather than creating new fakes; tests must stay
stable under the `Max` plan (random order + TSan).
