# TokenBar

> A native macOS menu-bar dashboard for AI coding quotas, pairing the upstream **CodexBar** ecosystem with a notch-friendly consolidated panel and Claude-inspired quota psychology.

TokenBar brings unified, glanceable visibility to all your AI coding assistant quotas (Claude, Codex, Antigravity, Cursor, Grok, and 48+ other providers) without cluttering your menu bar or hiding metrics behind multiple clicks.

```
┌────────────────────────────────────────────────────────┐
│  TokenBar                           4 providers        │
├────────────────────────────────────────────────────────┤
│  Claude                                       ACTIVE ● │
│  5-hour limit              Resets in 2 hr 45 min   38% │
│  █████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  Weekly · all models       Resets Fri 9:00 AM      18% │
│  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│                                                        │
│  Cursor                                       ACTIVE ● │
│  Total                     Resets in 28 days       14% │
│  ███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  Cursor (Fast)             Resets in 28 days       18% │
│  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│                                                        │
│  Antigravity                                  ACTIVE ● │
│  Gemini 5-hour             Resets in 1 hr 12 min   25% │
│  ██████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  Claude/GPT 5-hour         Resets in 3 hr 50 min    0% │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│  Weekly                    Resets Fri 9:00 AM      10% │
│  ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│                                                        │
│  Grok                                         ACTIVE ● │
│  Weekly                    Resets Sun 11:59 PM     42% │
│  ██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
├────────────────────────────────────────────────────────┤
│  ↻ Refresh All             Updated 2 min ago           │
│  ⚙ Settings…               •                      Quit │
└────────────────────────────────────────────────────────┘
```

---

## Core Design Principles

### 1. Zero-Click Level 1 Glanceability
Traditional menu bar monitors force you to hover over individual submenus or click each provider card to inspect rate windows. TokenBar consolidates all active providers into a single unified popover:
- **0 provider clicks**: Open the panel and immediately see every rate window across all enabled providers.
- **Adaptive zero-scroll sizing**: Dynamically computes content height so typical configurations (1–10 providers) fit cleanly on MacBook screens without scrollbars.
- **Zero-lag first mouse response**: Custom `FirstMouseHostingView` ensures footer actions (`Refresh All`, `Settings…`, `Quit`) respond on the first click even when the panel is inactive.

### 2. Claude-Inspired Quota Mental Model
Rather than misleading "remaining quota" percentages or artificial gamification, TokenBar models quota consumption factually:

$$\text{Usage accumulated in current window} + \text{Exact reset deadline}$$

- **Left-to-right fill**: Quota bars grow left-to-right from 0% to 100% as tokens are consumed, with visible background tracks.
- **Side-by-side metrics**: Prominent reset deadlines and consumed percentages appear side-by-side on the same baseline.
- **Always Countdown 5-Hour Limits**: Session windows (`5-hour limit`, `Gemini 5-hour`, `Claude/GPT 5-hour`) always display a dynamic relative countdown (`Resets in 2 hr 45 min`), exactly like the Claude desktop app. Weekly and monthly windows display absolute calendar dates (`Resets Fri 9:00 AM`, `Resets Oct 2, 9:34 PM`).

---

## Menu Bar Presentation Modes

Choose how TokenBar sits in your macOS menu bar via **Settings → General** or right-click context menu:

| Mode | Appearance | Ideal For |
| :--- | :--- | :--- |
| **Automatic (Default)** | 1–3 providers inline; collapses to single icon when 4+ enabled | Balancing glanceability with MacBook Pro notch constraints |
| **Hybrid / Overflow** | Keeps top $N$ (1–3) providers in the menu bar with a `+N` badge | Keeping primary tools visible while keeping secondary quotas 1 hover away |
| **Horizontal / Classic** | All enabled providers rendered side-by-side inline | Large external displays and classic `CodexBarMenuBar` users |
| **Vertical / Single Icon** | Exactly ONE dynamic Quota Clock icon | Minimalists and crowded menu bars |

---

## The Dynamic Quota Clock

TokenBar features a custom vector menu-bar icon designed for dark and light macOS appearances:
- **60-Step Circular Ring**: 60 discrete arc steps count down clockwise toward the reset deadline of your selected orbit provider.
- **Consumed Quota Bar**: Center bar fills left-to-right with consumed quota and transitions to warning colors at high utilization.
- **Counter-Clockwise Loading Animation**: During background refreshes or initial launch, the ring animates smoothly counter-clockwise at 20 FPS, indicating active network sync.
- **Configurable Orbit Window**: Bind the menu-bar clock to any provider and window (e.g. Claude Session, Antigravity Gemini, Cursor Total).

---

## Multi-Window Provider Normalization

TokenBar automatically parses and normalizes complex upstream rate-limit schemas:

- **Cursor**: Decodes all 4 distinct rate windows: `Total`, `Cursor (Fast)`, `Third Party`, and `Grok Bot`, with extended date formatting for long rolling periods (`Resets in 28 days` / `Resets Oct 2, 9:34 PM`).
- **Claude**: Distinct `5-hour limit`, `Weekly · all models`, and `Weekly · Fable / Sonnet` tiers.
- **Codex**: `5-hour limit`, `Weekly`, and `gpt-reserve` windows.
- **Antigravity**: Dual 5-hour quotas (`Gemini 5-hour` and `Claude/GPT 5-hour`) plus weekly allowance.
- **Grok**: `Weekly` and `On-demand` rate windows.
- **Full Ecosystem**: DeepSeek, Copilot, Windsurf, Ollama, OpenRouter, and 40+ more via CodexBar CLI.

---

## Status Bar Context Menu

Right-click (or Control-click) the menu-bar item anytime for direct control:

- **Open / Close Quota Panel**: Quick toggle without requiring mouse hover.
- **Refresh All** (`⌘R`): Trigger concurrent CLI queries across all enabled providers.
- **Presentation Mode ▸**: Instantly switch between Automatic, Hybrid, Horizontal, and Vertical modes.
- **Reset Time Format ▸**: Toggle "Always Countdown 5-Hour Limits" and clock time displays on the fly.
- **Settings…** (`⌘,`): Open the resizable preferences window.
- **Quit TokenBar** (`⌘Q`): Clean application shutdown.

---

## Zero-Setup Upstream Migration

If you already use `CodexBarMenuBar`, TokenBar automatically detects and imports your preferences on first launch:
- Enabled provider list and custom display ordering.
- Refresh interval and display preferences.
- Per-window bar, countdown, and percentage toggles.
- Upstream configuration files (`com.lobo.CodexBarMenuBar.plist`) remain untouched.

---

## Build & Installation

### Prerequisites
- macOS 14.0+ (Sonoma or Sequoia)
- Xcode 15+ command line tools
- [CodexBar CLI](https://github.com/steipete/CodexBar) installed (`brew install steipete/tap/codexbar` or placed in `~/.local/bin` / `/usr/local/bin` / `/opt/homebrew/bin`)

### Commands

```bash
# Clone the repository
git clone https://github.com/uncle9x9/TokenBar.git
cd TokenBar

# Run the complete test suite (36 unit tests)
make test

# Verify live CLI query bridge against installed providers
make verify

# Build and package the release application bundle
make package

# Launch TokenBar
open dist/TokenBar.app
```

---

## Upstream Alignment & Versioning

TokenBar tracks the upstream releases of the CodexBar ecosystem:
- **Core CLI Engine**: [steipete/CodexBar](https://github.com/steipete/CodexBar) v0.60.0
- **Base Menu Bar Architecture**: [Lobobodev/CodexBarMenuBar](https://github.com/Lobobodev/CodexBarMenuBar) v0.32.4
- **TokenBar App Version**: `0.32.4` (Build `324`)

---

## License

MIT License. Copyright © 2026 TokenBar Authors.  
Based on CodexBarMenuBar (© 2026 LoboAI, MIT) and CodexBar (© 2026 Peter Steinberger, MIT).
