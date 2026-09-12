import XCTest
@testable import TokenBarCore

final class ResetTimeFormatterTests: XCTestCase {
    func testCountdownDescription() {
        let now = Date()

        // 30 seconds -> now
        let soon = now.addingTimeInterval(0.5)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: soon, now: now), "now")

        // 45 minutes
        let in45m = now.addingTimeInterval(45 * 60)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: in45m, now: now), "45m")

        // 2 hours 15 minutes
        let in2h15m = now.addingTimeInterval(2 * 3600 + 15 * 60)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: in2h15m, now: now), "2h 15m")

        // 2 days 13 hours
        let in2d13h = now.addingTimeInterval(2 * 86400 + 13 * 3600)
        XCTAssertEqual(ResetTimeFormatter.countdownDescription(from: in2d13h, now: now), "2d 13h")

        // 5 days exactly
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
}
