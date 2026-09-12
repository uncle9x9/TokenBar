# TokenBar

> Presentation extension for CodexBarMenuBar with Claude Code-inspired quota psychology and notch-friendly consolidation.

TokenBar is a native macOS menu-bar dashboard that tracks quotas and usage windows for AI coding providers.

```
  TokenBar
  ──────────────────────────────────────
  Claude                          20%  ›  ──►  ┌──────────────────────────────┐
  Codex                            0%  ›       │ Claude                       │
  Antigrav                        24%  ›       │ codexbar usage --provider... │
  ──────────────────────────────────────       │ ──────────────────────────── │
  Refresh All                     (⌘R)         │ 5-hour                       │
  Settings…                       (⌘,)         │ Resets in 25 min         20% │
  Quit TokenBar                   (⌘Q)         │ ████░░░░░░░░░░░░░░░░░░░░░░░░ │
                                               │                              │
                                               │ Weekly · all models          │
                                               │ Resets Fri 8:59 AM       18% │
                                               │ ███░░░░░░░░░░░░░░░░░░░░░░░░░ │
                                               │                              │
                                               │ Weekly · Fable               │
                                               │ Resets Fri 9:00 AM        0% │
                                               │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
                                               │ ──────────────────────────── │
                                               │ Account: uncle9.ai@gmail.com │
                                               │ Source:  web                 │
                                               │ Updated: Just now            │
                                               └──────────────────────────────┘
```

---

## The Concept

TokenBar is a **presentation extension of CodexBarMenuBar**, adding vertical multi-provider consolidation without destroying the original UX:

```
Existing CodexBarMenuBar UX
            +
Optional single-icon vertical multi-provider view
            =
TokenBar
```

### 1. Presentation Modes

- **Automatic (Default)**: Automatically preserves the classic horizontal merged layout when 1–3 providers are enabled, and cleanly consolidates into a single TokenBar icon when 4+ providers are enabled to avoid crowding the MacBook Pro notch.
- **Horizontal / Original**: The authentic `CodexBarMenuBar` multi-item or merged horizontal status-bar layout.
- **Vertical / Single Icon**: Exactly ONE compact icon in the menu bar with native vertical dropdown and secondary detail cards.

### 2. Claude Code Behavioural Model

Instead of confusing "remaining %", TokenBar adopts the Claude Code mental model:

$$\text{Usage accumulated in the current window} + \text{Exactly when that window resets}$$

- **Three instant answers**:
  1. *“How much have I used?”* → Progress bar grows left-to-right from 0% toward 100% as quota is consumed.
  2. *“When does it reset?”* → Prominently displayed deadline (`Resets in 25 min`, `Resets Fri 8:59 AM`).
  3. *“Which quota window is this?”* → Clearly labeled window (`5-hour`, `Weekly · all models`, `Weekly · Fable`, `Gemini 5-hour`, etc.).
- **Neutral and factual**: No artificial urgency, gamification, or glowing warnings.

---

## Features

- **Quota Clock icon**: The menu-bar ring counts down to the selected quota reset in 60 steps, starting at twelve o’clock. The center bar fills left to right with consumed quota and turns red at 100%. It adapts to light and dark menu bars.
- **Clock source**: Settings → General → Quota Clock defaults to the first enabled provider in display order. Choose a specific provider (including Claude Code / Anthropic) and Session or Weekly. The clock always appears in single-icon mode and can optionally accompany horizontal provider details.
- **Honest reset states**: A dashed ring means the reset duration is unavailable; an outlined bar means usage is unavailable. At the reset deadline, the ring empties while reported usage remains until the next provider refresh confirms the new quota. This indicator reports quota; it does not block provider access.
- **Application identity**: The packaged app includes the selected blue Quota Orbit icon for Finder and application surfaces. Menu-bar rendering uses the same ring-and-bar identity with live data.

- **Upstream Asset & UI Fidelity**: Direct integration of upstream vector SVG icons, typography, spacing, and 3-tab Settings window (`General`, `Providers`, `About`).
- **Zero-Setup Migration**: Seamlessly imports your preferences, provider order, refresh interval, and custom window settings directly from `com.lobo.CodexBarMenuBar.plist`.
- **Parallel CLI Bridge**: Runs background queries concurrently across enabled providers via `codexbar usage --provider <id> --format json`.
- **Native macOS Submenus**: Provider detail cards are accessible via standard macOS menu items—no floating HUDs or detached windows.
- **All 48+ Providers Supported**: Claude, Codex, Gemini, Antigravity, Cursor, Copilot, DeepSeek, OpenRouter, Windsurf, Ollama, and more.

---

## Build & Installation

### Requirements
- macOS 14.0+ (Sonoma or Sequoia)
- Xcode 15+ command line tools
- [CodexBar CLI](https://github.com/steipete/CodexBar) (`brew install codexbar` or manual install)

### Build & Run
```bash
# Clone the repository
git clone https://github.com/uncle9x9/TokenBar.git
cd TokenBar

# Run tests
make test

# Verify live CLI queries
make verify

# Build and package TokenBar.app
make package

# Launch TokenBar
open dist/TokenBar.app
```

---

## License

MIT License. Copyright © 2026 TokenBar Authors. Based on CodexBarMenuBar (© 2026 LoboAI, MIT) and CodexBar (© 2026 Peter Steinberger, MIT).
