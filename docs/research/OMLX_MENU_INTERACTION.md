# oMLX Menu Interaction Research Report

## 1. Executive Summary

oMLX (`jundot/omlx`) features a macOS menu bar status item with a secondary detail flyout ("System Stats") that provides rich, real-time metrics without cluttering the menu bar. This report analyzes the exact mechanics of that interaction, identifies what makes it robust, and defines what TokenBar will adopt and what it will discard.

---

## 2. Relevant Files and Symbols

### Core Menu Architecture (`apps/omlx-mac/Sources/Menubar/`)
- [`MenubarController.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/omlx/apps/omlx-mac/Sources/Menubar/MenubarController.swift):
  - `MenubarController`: Owns the root `NSStatusItem` and `NSMenu`.
  - `systemStatsParentItem`: Parent `NSMenuItem` labeled "System Stats".
  - `systemStatsSubmenu`: Child `NSMenu` assigned to `systemStatsParentItem.submenu`.
  - `panelItem(hosting:)`: Utility function wrapping an `NSHostingView<AnyView>` inside an `NSMenuItem` (`view.frame.size = view.fittingSize; item.view = view; item.isEnabled = false`).
  - `NSMenuDelegate` conformance: Hooks `menuWillOpen(_:)` and `menuDidClose(_:)` to start/stop live updates.
- [`SystemStatsPanels.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/omlx/apps/omlx-mac/Sources/Menubar/SystemStatsPanels.swift):
  - Value-driven SwiftUI views: `CPUStatsPanel`, `GPUStatsPanel`, `MemoryStatsPanel`.
  - Layout constants: `panelWidth: CGFloat = 270`.
  - `UsageBarRow`: Horizontal label + value with a proportional `Capsule` progress bar.
  - `StatsValueRow`: Key-value pair with secondary label and primary mono/regular value.
- [`SystemStatsSampler.swift`](file:///Volumes/990EP4T/AgentPlayground/TokenBar/.research/omlx/apps/omlx-mac/Sources/Menubar/SystemStatsSampler.swift):
  - Formats bytes, percentages, and uptimes.

---

## 3. Status Item and Menu Implementation

- **Status Item**: Single `NSStatusItem` initialized via `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)`.
- **Root Menu**: Standard `NSMenu` assigned to `statusItem.menu`.
- **Submenu Hierarchy**:
  ```
  [NSStatusItem (Menu Bar Icon)]
         │
         ▼
  ┌─────────────────────────────────┐
  │ NSMenu (Root)                   │
  │  • Status Header                │
  │  • Provider / Metric Item 1  ───┼────────► ┌───────────────────────────┐
  │  • Provider / Metric Item 2  ───┼──►       │ NSMenu (Submenu)          │
  │  • Provider / Metric Item 3  ───┼──►       │  • NSMenuItem (Custom View)│
  │  ─────────────────────────────  │          │    └─ NSHostingView       │
  │  • Refresh                      │          │        └─ DetailCardView  │
  │  • Settings                     │          └───────────────────────────┘
  │  • Quit                         │
  └─────────────────────────────────┘
  ```

---

## 4. Hover, Highlight, and Submenu Behavior

1. **Native Hover Tracking**:
   - By assigning an `NSMenu` to `parentItem.submenu`, macOS automatically handles mouse hover, highlight delay, mouse tracking hysteresis, and disclosure chevron rendering.
   - There is no need for manual `NSTrackingArea`, coordinate translation, or floating `NSPanel` windows.
2. **SwiftUI Hosting**:
   - `NSHostingView(rootView: ...)` embeds declarative SwiftUI components directly into the AppKit menu hierarchy.
   - Setting `item.isEnabled = false` ensures the detail card is purely informative and prevents accidental click-dismissals.
3. **RunLoop Management**:
   - Menu tracking places the main run loop into `NSEventTrackingRunLoopMode`.
   - oMLX schedules timers in `RunLoop.main` using `.commonModes` so state updates continue while the menu is actively being browsed.

---

## 5. Positioning, Dismissal, and Stability

- **Positioning**: AppKit automatically positions submenus to the right (or left if near the right display edge) and handles vertical flipping near screen boundaries.
- **Dismissal**: When the root menu dismisses (user clicks outside or presses Escape), the entire submenu tree dismisses atomically.
- **Stability**: Because submenus are native `NSMenu` instances owned by the window server:
  - No flickering between hover transitions.
  - No stranded floating panels.
  - No focus stealing from foreground apps.

---

## 6. What TokenBar Will Reuse Conceptually

1. **Native `NSMenu` Submenu Pattern**:
   - Each provider in the root overview menu has an attached `NSMenu` containing an `NSHostingView`-hosted detail panel.
2. **Value-Driven SwiftUI Detail Cards**:
   - Fixed panel width (e.g. 260–280 pt).
   - Capsule progress bars for session, weekly, and extra quotas.
   - Clean macOS typography (system sans-serif + monospaced digits).
   - Clear reset countdowns, account metadata, and last-updated timestamps.
3. **Lifecycle Management**:
   - Pause UI redraws when the menu is closed; update swiftly upon `menuWillOpen`.

---

## 7. What TokenBar Will NOT Copy

- **Hardware System Metrics**: Mach port kernel calls, CPU core allocations, GPU memory buffers.
- **Backend Process Management**: Local python servers, subprocess lifecycles, and network socket management.
- **Multi-Status-Item Sprawl**: oMLX allows toggling separate status items for LIV, AVG, ALL metrics; TokenBar strictly adheres to **ONE** status item to protect the MacBook Pro notch area.
- **Heavy ViewModels**: Keep the TokenBar presentation layer lean, reactive, and driven by the CodexBar data snapshot.
