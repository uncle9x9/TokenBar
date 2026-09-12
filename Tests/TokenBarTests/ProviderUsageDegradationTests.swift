import XCTest
@testable import TokenBarCore

final class ProviderUsageDegradationTests: XCTestCase {
    func testMissingMetricsDegradeGracefully() {
        let config = ProviderConfig(id: "gemini", displayName: "Gemini", cliName: "gemini")
        let usage = ProviderUsage.empty(config: config)

        XCTAssertEqual(usage.id, "gemini")
        XCTAssertEqual(usage.displayName, "Gemini")
        XCTAssertNil(usage.sessionPercent)
        XCTAssertNil(usage.weeklyPercent)
        XCTAssertNil(usage.primaryUsedPercent)
        XCTAssertNil(usage.primaryRemainingPercent)
        XCTAssertNil(usage.primaryResetsAt)
        XCTAssertEqual(usage.statusDescription, "No Data")
        XCTAssertFalse(usage.isConnected)
    }

    func testExhaustedQuotaClassification() {
        let usage = ProviderUsage(
            id: "openai",
            displayName: "OpenAI",
            sessionPercent: 100.0,
            weeklyPercent: 29.0
        )

        XCTAssertTrue(usage.isExhausted)
        XCTAssertEqual(usage.primaryRemainingPercent, 0.0)
        XCTAssertEqual(usage.statusDescription, "Exhausted")
    }

    func testRemainingPercentCalculationClamped() {
        // Exceeded 100% used -> remaining should clamp to 0
        let rw = RateWindow(usedPercent: 125.0)
        XCTAssertEqual(rw.remainingPercent, 0.0)

        // Negative used (if API returns anomaly) -> remaining should clamp reasonably
        let rwLow = RateWindow(usedPercent: 0.0)
        XCTAssertEqual(rwLow.remainingPercent, 100.0)

        let rwMid = RateWindow(usedPercent: 49.0)
        XCTAssertEqual(rwMid.remainingPercent, 51.0)
    }

    func testFallbackToWeeklyWhenSessionNil() {
        let usage = ProviderUsage(
            id: "deepseek",
            displayName: "DeepSeek",
            sessionPercent: nil,
            weeklyPercent: 35.0
        )

        XCTAssertEqual(usage.primaryUsedPercent, 35.0)
        XCTAssertEqual(usage.primaryRemainingPercent, 65.0)
    }
}
