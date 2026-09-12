import XCTest
import AppKit
@testable import TokenBarCore

final class QuotaClockIconTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func usage(_ percent: Double = 25, remaining: Double = 9000, minutes: Int? = 300) -> ProviderUsage {
        ProviderUsage(id: "claude", displayName: "Claude", sessionPercent: percent,
                      sessionWindowMinutes: minutes, sessionResetsAt: now.addingTimeInterval(remaining))
    }

    func testCountdownUsesRealWindowDurationAndSixtySteps() {
        XCTAssertEqual(QuotaClockState(usage: usage(remaining: 18000), now: now).remainingSteps, 60)
        XCTAssertEqual(QuotaClockState(usage: usage(), now: now).remainingSteps, 30)
        XCTAssertEqual(QuotaClockState(usage: usage(remaining: 1), now: now).remainingSteps, 1)
        XCTAssertEqual(QuotaClockState(usage: usage(remaining: 30000), now: now).remainingSteps, 60)
    }

    func testResetDoesNotInventRestoredQuota() {
        let state = QuotaClockState(usage: usage(100, remaining: -1), now: now)
        XCTAssertEqual(state.remainingSteps, 0)
        XCTAssertTrue(state.awaitingReset)
        XCTAssertTrue(state.exhausted)
        XCTAssertTrue(state.description(provider: "Claude", window: "Session", now: now).contains("awaiting reset"))
        XCTAssertFalse(QuotaClockState(usage: usage(0, remaining: 18000), now: now).exhausted)
    }

    func testUnknownAndErrorAreNotShownAsAvailable() {
        XCTAssertNil(QuotaClockState(usage: nil, now: now).usedFraction)
        for invalid in [-1.0, Double.nan, Double.infinity] {
            XCTAssertNil(QuotaClockState(usage: usage(invalid), now: now).usedFraction)
        }
        var failed = usage()
        failed.error = "offline"
        XCTAssertNil(QuotaClockState(usage: failed, now: now).remainingSteps)
        XCTAssertNil(QuotaClockState(usage: failed, now: now).usedFraction)
        let missingDuration = QuotaClockState(usage: usage(minutes: nil), now: now)
        XCTAssertNil(missingDuration.remainingSteps)
        XCTAssertEqual(missingDuration.usedFraction, 0.25)
    }

    func testSelectedWindowKeepsBarAndClockTogether() {
        var data = usage()
        data.weeklyPercent = 100
        data.weeklyWindowMinutes = 10080
        data.weeklyResetsAt = now.addingTimeInterval(10080 * 30)
        let weekly = QuotaClockState(usage: data, windowID: "weekly", now: now)
        XCTAssertEqual(weekly.remainingSteps, 30)
        XCTAssertTrue(weekly.exhausted)
        XCTAssertFalse(QuotaClockState(usage: data, now: now).exhausted)
        data.weeklyPercent = nil
        XCTAssertNil(QuotaClockState(usage: data, windowID: "weekly", now: now).usedFraction)
    }

    func testFinalCountdownStepStillDrawsAnArc() {
        let finalStep = QuotaClockIcon.render(state: QuotaClockState(usage: usage(remaining: 1), now: now))
        let elapsed = QuotaClockIcon.render(state: QuotaClockState(usage: usage(remaining: 0), now: now))
        XCTAssertNotEqual(finalStep.tiffRepresentation, elapsed.tiffRepresentation)
    }

    func testTemplateAndExhaustionRendering() {
        let normal = QuotaClockIcon.render(state: QuotaClockState(usage: usage(), now: now))
        XCTAssertTrue(normal.isTemplate)
        XCTAssertEqual(normal.size, NSSize(width: 18, height: 18))
        let full = QuotaClockState(usage: usage(120), now: now)
        XCTAssertEqual(full.usedFraction, 1)
        let light = QuotaClockIcon.render(state: full, dark: false)
        let dark = QuotaClockIcon.render(state: full, dark: true)
        XCTAssertFalse(light.isTemplate)
        XCTAssertNotNil(light.tiffRepresentation)
        XCTAssertNotEqual(light.tiffRepresentation, dark.tiffRepresentation)
    }
}
