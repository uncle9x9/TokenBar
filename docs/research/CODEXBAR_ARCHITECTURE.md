# CodexBar Architecture Research Report

## 1. Executive Summary

CodexBar (`steipete/CodexBar`) is an established macOS menu-bar quota tracker for AI coding assistants. This document captures its architecture, data models, refresh loop, and menu-rendering pipeline to establish the optimal, clean integration boundary for **TokenBar**.

---

## 2. Relevant Files and Symbols

### Core Modules (`Sources/CodexBarCore`)
- [`UsageFetcher.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBarCore/UsageFetcher.swift):
  - `UsageSnapshot`: Primary data transfer object containing `primary: RateWindow?`, `secondary: RateWindow?`, `tertiary: RateWindow?`, `extraRateWindows: [NamedRateWindow]?`, `updatedAt: Date`, and `identity: ProviderIdentitySnapshot?`.
  - `RateWindow`: Represents quota windows with `usedPercent: Double`, `windowMinutes: Int?`, `resetsAt: Date?`, `resetDescription: String?`, and `remainingPercent: Double` (`max(0, 100 - usedPercent)`).
  - `NamedRateWindow`: Keyed quota window with `id: String`, `title: String`, and `window: RateWindow`.
  - `ProviderFetchResult`: Encapsulates fetch outcomes, warnings, errors, and metadata.
- [`Providers/Providers.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBarCore/Providers/Providers.swift):
  - `UsageProvider`: Enum of supported providers (`codex`, `claude`, `gemini`, `antigravity`, `cursor`, `copilot`, `windsurf`, etc.).
- [`ProviderDescriptor.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBarCore/ProviderDescriptor.swift):
  - `ProviderDescriptor`: Single source of truth for metadata (`displayName`, `sessionLabel`, `weeklyLabel`, `defaultEnabled`), branding (colors, icon resources), and fetch pipeline.
- [`Config/CodexBarConfig.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBarCore/Config/CodexBarConfig.swift):
  - Reads `~/.config/codexbar/config.json` for provider source modes, API tokens, cookie preferences, and accounts.

### App & UI Modules (`Sources/CodexBar`)
- [`UsageStore.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBar/UsageStore.swift):
  - Central `@MainActor` state store managing background refresh cycles, rate limiting, error coalescing, and snapshot caching across providers.
- [`SettingsStore.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBar/SettingsStore.swift):
  - User preferences: enabled providers, ordering, refresh intervals, appearance, and Merge Icons preferences.
- [`StatusItemController.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBar/StatusItemController.swift):
  - Manages `NSStatusItem` instances in the macOS menu bar.
- [`StatusItemController+Menu.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBar/StatusItemController+Menu.swift):
  - Assembles `NSMenu`, custom `NSMenuItem` hosting views via `makeMenuCardItem`, separators, and persistent actions (Refresh, Settings, Quit).
- [`StatusItemController+OverviewSubmenus.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBar/StatusItemController+OverviewSubmenus.swift):
  - Logic for attaching submenus to Overview items (`makeOverviewRowSubmenu`) and switching active providers (`selectOverviewProvider`).
- [`StatusItemController+MenuTypes.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/CodexBar/Sources/CodexBar/StatusItemController+MenuTypes.swift):
  - SwiftUI rows such as `OverviewMenuCardRowView` and header components.

### CLI Target (`Sources/CodexBarCLI`)
- Exposes `codexbar usage --format json [--provider <id>|all]` which emits machine-readable JSON snapshots matching `UsageSnapshot` fields.

---

## 3. Provider → UsageSnapshot Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Provider Probes                         │
│  (CLI runner / Web cookies / OAuth token / Local session)    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    ProviderFetchStrategy                    │
│      Produces ProviderFetchResult with UsageSnapshot        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                         UsageStore                          │
│     Maintains [UsageProvider: UsageSnapshot], errors,       │
│     and coalesces refresh requests                          │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    StatusItemController                     │
│     Updates NSStatusItem icon & rebuilds NSMenu hierarchy   │
└─────────────────────────────────────────────────────────────┘
```

1. **Strategy Resolution**: Each provider descriptor specifies an ordered pipeline of `ProviderFetchStrategy` instances (e.g. OAuth API → Web cookie scrape → CLI).
2. **Fetch Execution**: `UsageFetcher` runs the strategies with bounded timeouts and error-handling fallback.
3. **Snapshot Ingestion**: `UsageStore` updates its in-memory dictionary of snapshots, timestamps, and fetch errors.
4. **Presentation**: UI listeners rebuild status items or mark menu items dirty.

---

## 4. Menu Construction and Overview Implementation

In CodexBar:
- **Status Item Hosting**: AppKit `NSStatusItem` in `.variableLength` or custom image template mode.
- **Merge Icons Mode**: Instead of vending 10+ status items, CodexBar offers a merged mode that renders a provider switcher bar or an **Overview** tab.
- **Overview Rows**: Lines 624–655 of `StatusItemController+Menu.swift` generate a vertical stack of rows (`OverviewMenuCardRowView`).
- **Submenus**: CodexBar historically attaches submenus only for optional secondary data (e.g. cost charts or storage breakdowns), while selecting an overview row jumps the main menu to that provider's full card.
- **Card Items**: Views are hosted in AppKit menus via `NSHostingView` wrapped in an `NSMenuItem` with `item.view = hostingView`.

---

## 5. Reusable Quota & Detail-Card Concepts

To maintain fidelity with the CodexBar data model:
1. **Window Semantics**:
   - `primary`: Shortest/active session quota (e.g., 5-hour limit for Claude, 3-hour limit for Codex).
   - `secondary`: Longer quota (e.g., weekly limit for Claude/Codex).
   - `tertiary` / `extraRateWindows`: Additional windows (e.g., Opus carve-out, custom model allowances, GPT-4 review quota).
2. **Truthful Degradation**:
   - Never invent or fabricate a quota. If a window is missing (`nil`), omit the bar or show `—`.
   - Never display balance/credits as a percentage bar; balance-based providers show currency or credit quantities.
3. **Reset Time Presentation**:
   - Countdown relative style (`in 2h 15m`, `in 3d 4h`) or absolute timestamp (`tomorrow, 14:00`).

---

## 6. Minimal Integration Boundary for TokenBar

Rather than reimplementing 50+ provider scraping and OAuth authentication mechanisms:
1. **Data Ingestion Boundary**:
   - TokenBar leverages the standardized `UsageSnapshot` / `CodexBarResponse` schema.
   - It interfaces with the local `codexbar` CLI (`/opt/homebrew/bin/codexbar usage --format json`) or direct snapshot models.
   - This decouples presentation and interaction from upstream protocol churn, allowing TokenBar to track all CodexBar-supported providers immediately with zero code duplication.
2. **UI & Interaction Boundary**:
   - TokenBar owns the single macOS menu-bar icon, vertical provider list, and native hover/highlight detail panels.
