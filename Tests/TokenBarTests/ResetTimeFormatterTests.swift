import XCTest
@testable import TokenBarCore

final class ResetTimeFormatterTests: XCTestCase {
    func testClaudeCodeSmartResetFormatting() {
        let now = Date()

        // 31 minutes -> "Resets in 31 min"
        let in31m = now.addingTimeInterval(31 * 60)
        XCTAssertEqual(ResetTimeFormatter.resetLine(date: in31m, now: now), "Resets in 31 min")

        // 2 hours 14 minutes -> "Resets in 2 hr 14 min"
        let in2h14m = now.addingTimeInterval(2 * 3600 + 14 * 60)
        XCTAssertEqual(ResetTimeFormatter.resetLine(date: in2h14m, now: now), "Resets in 2 hr 14 min")

        // 5 hours exactly -> "Resets in 5 hr"
        let in5h = now.addingTimeInterval(5 * 3600)
        XCTAssertEqual(ResetTimeFormatter.resetLine(date: in5h, now: now), "Resets in 5 hr")

        // In 3 days -> Should contain day of week e.g. "Resets ..."
        let in3d = now.addingTimeInterval(3 * 86400)
        let line3d = ResetTimeFormatter.resetLine(date: in3d, now: now)
        XCTAssertNotNil(line3d)
        XCTAssertTrue(line3d!.starts(with: "Resets "), "Expected 'Resets ' prefix")
    }

    func testQuotaWindowNormalisation() {
        let now = Date()

        // Test Claude normalisation: 5-hour, Weekly · all models, Weekly · Fable
        let claudeConfig = ProviderConfig.byID["claude"]!
        let claudeUsage = ProviderUsage(
            id: "claude",
            displayName: "Claude",
            sessionPercent: 20.0,
            sessionWindowMinutes: 300,
            sessionResetsAt: now.addingTimeInterval(31 * 60),
            weeklyPercent: 18.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: now.addingTimeInterval(5 * 86400),
            extraWindows: [
                ExtraWindowUsage(id: "claude-weekly-scoped-fable", title: "Fable only", usedPercent: 0.0, resetsAt: now.addingTimeInterval(5 * 86400))
            ]
        )

        let claudeWindows = claudeUsage.normalisedQuotaWindows(config: claudeConfig)
        XCTAssertEqual(claudeWindows.count, 3)
        XCTAssertEqual(claudeWindows[0].title, "5-hour limit")
        XCTAssertEqual(claudeWindows[0].usedPercent, 20.0)
        XCTAssertEqual(claudeWindows[0].resetText, "Resets in 31 min")

        XCTAssertEqual(claudeWindows[1].title, "Weekly · all models")
        XCTAssertEqual(claudeWindows[1].usedPercent, 18.0)

        XCTAssertEqual(claudeWindows[2].title, "Weekly · Fable")
        XCTAssertEqual(claudeWindows[2].usedPercent, 0.0)

        // Test Antigravity normalisation: preserves explicit labeled windows
        let antigravConfig = ProviderConfig.byID["antigravity"]!
        let antigravUsage = ProviderUsage(
            id: "antigravity",
            displayName: "Antigrav",
            extraWindows: [
                ExtraWindowUsage(id: "g-5h", title: "Gemini 5-hour", usedPercent: 20.5, resetsAt: now.addingTimeInterval(2 * 3600)),
                ExtraWindowUsage(id: "g-w", title: "Gemini weekly", usedPercent: 5.3, resetsAt: now.addingTimeInterval(3 * 86400)),
                ExtraWindowUsage(id: "c-5h", title: "Claude/GPT 5-hour", usedPercent: 0.0, resetsAt: now.addingTimeInterval(5 * 3600)),
                ExtraWindowUsage(id: "c-w", title: "Claude/GPT weekly", usedPercent: 4.6, resetsAt: now.addingTimeInterval(3 * 86400))
            ]
        )

        let antigravWindows = antigravUsage.normalisedQuotaWindows(config: antigravConfig)
        XCTAssertEqual(antigravWindows.count, 4)
        XCTAssertEqual(antigravWindows[0].title, "Gemini 5-hour")
        XCTAssertEqual(antigravWindows[1].title, "Gemini weekly")
        XCTAssertEqual(antigravWindows[2].title, "Claude/GPT 5-hour")
        XCTAssertEqual(antigravWindows[3].title, "Claude/GPT weekly")
    }

    func testCountdownDescription() {
        let now = Date()

        let soon = now.addingTimeInterval(0.5)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: soon, now: now), "now")

        let in45m = now.addingTimeInterval(45 * 60)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: in45m, now: now), "45 min")

        let in2h15m = now.addingTimeInterval(2 * 3600 + 15 * 60)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: in2h15m, now: now), "2 hr 15 min")

        let in2d13h = now.addingTimeInterval(2 * 86400 + 13 * 3600)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: in2d13h, now: now), "2d 13h")

        let in5d = now.addingTimeInterval(5 * 86400)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: in5d, now: now), "5d")
    }

    func testRelativeUpdatedDescription() {
        let now = Date()

        let justNow = now.addingTimeInterval(-2)
        XCTAssertEqual(ResetTimeFormatter.relativeUpdatedDescription(from: justNow, now: now), "Just now")

        let sec15 = now.addingTimeInterval(-15)
        XCTAssertEqual(ResetTimeFormatter.relativeUpdatedDescription(from: sec15, now: now), "15s ago")

        let min5 = now.addingTimeInterval(-300)
        XCTAssertEqual(ResetTimeFormatter.relativeUpdatedDescription(from: min5, now: now), "5m ago")

        let hour2 = now.addingTimeInterval(-7200)
        XCTAssertEqual(ResetTimeFormatter.relativeUpdatedDescription(from: hour2, now: now), "2h ago")
    }

    func testGrokQuotaNormalisationAndDistinctFromXAI() {
        let now = Date()

        // 1. Distinction: Grok (Consumer / SuperGrok usageBar) vs xAI (Developer API balance)
        let grokConfig = ProviderConfig.byID["grok"]
        let xaiConfig = ProviderConfig.byID["xai"]
        XCTAssertNotNil(grokConfig)
        XCTAssertNotNil(xaiConfig)

        XCTAssertEqual(grokConfig?.displayType, .usageBar, "Grok consumer subscription must use usageBar")
        XCTAssertEqual(grokConfig?.sessionField, .primary)
        XCTAssertEqual(grokConfig?.weeklyField, .secondary)

        XCTAssertEqual(xaiConfig?.displayType, .balance, "xAI developer platform must use balance")
        XCTAssertEqual(xaiConfig?.balanceField, .primary)

        // 2. Grok Quota Normalisation: Primary Weekly (4 days) + Secondary On-demand
        let grokUsage = ProviderUsage(
            id: "grok",
            displayName: "Grok",
            sessionPercent: 42.0,
            sessionWindowMinutes: 7 * 24 * 60,
            sessionResetsAt: now.addingTimeInterval(4 * 86400),
            weeklyPercent: 15.0,
            weeklyWindowMinutes: nil,
            weeklyResetsAt: nil
        )

        let grokWindows = grokUsage.normalisedQuotaWindows(config: grokConfig!)
        XCTAssertEqual(grokWindows.count, 2)
        XCTAssertEqual(grokWindows[0].title, "Weekly", "Primary Grok subscription quota window must be labeled Weekly")
        XCTAssertEqual(grokWindows[0].usedPercent, 42.0)
        XCTAssertEqual(grokWindows[1].title, "On-demand", "Secondary Grok quota window must be labeled On-demand")
        XCTAssertEqual(grokWindows[1].usedPercent, 15.0)

        // 3. Genuine Error State: Never invent quota data when upstream reports no fetch strategy / unauthenticated
        let unauthGrok = ProviderUsage(
            id: "grok",
            displayName: "Grok",
            error: "No available fetch strategy for grok."
        )
        XCTAssertFalse(unauthGrok.isConnected)
        XCTAssertEqual(unauthGrok.statusDescription, "Error")
        XCTAssertTrue(unauthGrok.normalisedQuotaWindows(config: grokConfig!).isEmpty, "Must not generate synthetic quota bars on error")
    }

    func testCursorMultiWindowNormalisationAndLongResetDate() {
        let now = Date()
        let cursorConfig = ProviderConfig.byID["cursor"]!

        // Test modern CodexBar 0.60.0 Cursor schema:
        // primary: Total (5.6% used), resets in 20 days
        // secondary: Cursor (5.3% used)
        // tertiary: Third Party (11.4% used)
        // extraRateWindows: Grok Bot (0.05% used)
        let in20Days = now.addingTimeInterval(20 * 86400)
        let cursorUsage = ProviderUsage(
            id: "cursor",
            displayName: "Cursor",
            sessionPercent: 5.6,
            sessionWindowMinutes: 43200,
            sessionResetsAt: in20Days,
            weeklyPercent: 5.3,
            weeklyWindowMinutes: 43200,
            weeklyResetsAt: in20Days,
            tertiaryPercent: 11.4,
            tertiaryWindowMinutes: 43200,
            tertiaryResetsAt: in20Days,
            extraWindows: [
                ExtraWindowUsage(id: "cursor-grok-bot", title: "Grok Bot", usedPercent: 0.05, resetsAt: now.addingTimeInterval(6 * 86400))
            ]
        )

        let windows = cursorUsage.normalisedQuotaWindows(config: cursorConfig, asAbsolute: true)
        XCTAssertEqual(windows.count, 4)
        XCTAssertEqual(windows[0].title, "Total")
        XCTAssertEqual(windows[0].usedPercent, 5.6)
        XCTAssertTrue(windows[0].resetText?.contains("Resets ") == true)

        XCTAssertEqual(windows[1].title, "Cursor")
        XCTAssertEqual(windows[1].usedPercent, 5.3)

        XCTAssertEqual(windows[2].title, "Third Party")
        XCTAssertEqual(windows[2].usedPercent, 11.4)

        XCTAssertEqual(windows[3].title, "Grok Bot")
        XCTAssertEqual(windows[3].usedPercent, 0.05)

        // Verify date > 7 days includes month and date in absolute description
        let resetAbs = ResetTimeFormatter.absoluteDescription(from: in20Days, now: now)
        XCTAssertFalse(resetAbs.hasPrefix("Fri "), "Dates beyond 7 days must include month name, not just weekday")
    }
}
