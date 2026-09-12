# TokenBar

> One menu-bar icon for all your AI coding quotas.

TokenBar is a lightweight, polished native macOS menu-bar dashboard that tracks quotas and remaining allowances for AI coding providers.

```
  TokenBar [5 providers]
  ─────────────────────────────────────
  ✦ Claude               51% ▰▰▰▱  ›  ──►  ┌──────────────────────────────┐
  ◉ OpenAI / Codex      100% ▰▰▰▰  ›       │ OPENAI / CODEX    [Connected]│
  ⚛ Gemini                0% ▱▱▱▱  ›       │ ──────────────────────────── │
  ⚡ Antigravity           0% ▱▱▱▱  ›       │ Current       100% remaining │
  ➤ Cursor               64% ▰▰▰▱  ›       │ ████████████████████████████ │
  ─────────────────────────────────────    │ Weekly         29% remaining │
  ↻ Refresh All               (⌘R)         │ ████████░░░░░░░░░░░░░░░░░░░░ │
  ⚙ Settings…                 (⌘,)         │ Code Review    13% remaining │
  ⏻ Quit TokenBar             (⌘Q)         │ ███░░░░░░░░░░░░░░░░░░░░░░░░░ │
                                           │ ──────────────────────────── │
                                           │ Reset:              in 2d 13h│
                                           │ Updated:           15 sec ago│
                                           │ Source:                 OAuth│
                                           │ Organization:     OpenAI Team│
                                           └──────────────────────────────┘
```

---

## Why TokenBar?

The MacBook Pro notch makes having multiple separate menu-bar status items impractical. If you use Claude Code, Codex, Gemini CLI, Antigravity, Cursor, and GitHub Copilot simultaneously, individual menu-bar items quickly crowd out your status bar and disappear behind the notch.

**TokenBar solves this by maintaining a strict, constant footprint of exactly ONE menu-bar icon**, regardless of whether you have 3, 10, or 30 providers enabled:

1. **One permanent entry point** in the macOS menu bar.
2. **Vertical provider overview** showing identity and primary quota at a glance.
3. **Native secondary detail panels** inspired by oMLX System Stats, revealed on hover/highlight with progress bars, reset countdowns, extra quota allowances, and account metadata.
4. **Zero flicker, zero focus stealing, zero stranded windows** thanks to standard AppKit menu hierarchy.

---

## Features

- **Constant Menu-Bar Footprint**: Uses only a single menu-bar item.
- **Native macOS Hover Flyouts**: Hovering or highlighting any provider smoothly expands a native detail panel with quota progress bars.
- **Multi-Window Quota Tracking**:
  - Current / session window (e.g., 3-hour or 5-hour limit).
  - Weekly window.
  - Provider-specific extra allowances (e.g., Claude Opus carve-outs, Codex Code Review quotas).
- **Truthful Degradation**: Never fabricates or guesses a quota. Unavailable metrics degrade gracefully to dashes or status badges.
- **Instant Background Refresh**: Manual refresh via `⌘R` or customizable periodic refresh intervals (1m, 2m, 5m, 15m, 30m, Manual).
- **Comprehensive Provider Support**: Works with all major AI coding platforms out of the box.
- **Native SwiftUI + AppKit**: Built for macOS 14+ Sonoma and macOS 15+ Sequoia with full Dark Mode and Accessibility support.

---

## Supported Providers

| Provider | Primary Quota | Secondary Quota | Extra Windows / Features |
| :--- | :--- | :--- | :--- |
| **Claude** | 5-hour session | Weekly allowance | Opus model allowance, Web / OAuth |
| **OpenAI / Codex** | Session limit | Weekly limit | Code review credits, GPT-4 allowances |
| **Gemini** | Session quota | Daily / weekly | Google AI Studio & Vertex AI limits |
| **Antigravity** | Session quota | Weekly budget | AGY SDK task allowances |
| **Cursor** | Fast requests | Monthly pool | Pro / Business quota tiers |
| **GitHub Copilot** | Premium requests | Monthly limit | Enterprise / Individual plans |
| **Windsurf** | Session quota | Monthly grant | Cascade allowances |
| **DeepSeek** | API balance | Usage credits | Real-time currency balance |
| **OpenRouter** | Credit balance | Rate limits | Remaining balance |
| **Others** | Session / Weekly | Varies | Qwen/Alibaba, Kimi, MiniMax, Kiro, ZAI, Droid |

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│             AI Provider Data Layer                     │
│  (CodexBar CLI / Providers / Local Session Probes)     │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ JSON
┌────────────────────────────────────────────────────────┐
│                    TokenBarCore                        │
│   • UsageSnapshot / RateWindow Data Models             │
│   • UsageStore (@MainActor State Coordinator)          │
│   • Background Refresh Timer & Coalescing              │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                      TokenBar                          │
│   • Single NSStatusItem                                │
│   • Root NSMenu (Vertical Provider Overview Rows)      │
│   • Hover/Highlight Submenus (ProviderDetailCardView)  │
│   • Settings & Preferences Window                      │
└────────────────────────────────────────────────────────┘
```

TokenBar interfaces with the standardized `CodexBarResponse` and `UsageSnapshot` models. By leveraging the existing local `codexbar` provider infrastructure, TokenBar focuses on delivering an unparalleled macOS presentation layer with zero duplication of unstable scraping logic.

---

## Installation

### Prerequisites
- macOS 14.0 or higher (Apple Silicon & Intel supported).
- [CodexBar](https://github.com/steipete/CodexBar) CLI installed (`brew install steipete/tap/codexbar` or installed via CodexBar.app).

### Build from Source
```bash
git clone https://github.com/uncle9x9/TokenBar.git
cd TokenBar

# Build release application bundle
./Scripts/package_app.sh

# Launch TokenBar
open dist/TokenBar.app
```

---

## Development

```bash
# Run unit tests
make test

# Build debug binary
make build

# Run acceptance verification suite
make verify

# Package release .app bundle
make package
```

---

## Privacy & Security

- **No Remote Telemetry**: TokenBar communicates exclusively with your local provider tools and APIs.
- **On-Device Only**: Credentials and session tokens remain securely in your local macOS Keychain or configuration files.
- **Open Source**: Complete transparency with clean, auditable Swift code.

---

## Upstream Inspiration & Credits

- **[CodexBar](https://github.com/steipete/CodexBar)** by Peter Steinberger (@steipete) — For pioneering the provider descriptors, fetching infrastructure, and shared usage models.
- **[oMLX](https://github.com/jundot/omlx)** by Jun (@jundot) — For the inspiration behind native macOS hover detail flyouts (System Stats).
- **[CodexBarMenuBar](https://github.com/Lobobodev/CodexBarMenuBar)** by Lobobodev — For demonstrating lightweight presentation layering over CodexBar data.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
