import XCTest
@testable import TokenBarCore

final class CodexBarJSONParsingTests: XCTestCase {
    func testDecodeNormalUsageResponse() throws {
        let json = """
        [
          {
            "provider": "claude",
            "usage": {
              "primary": {
                "usedPercent": 49.0,
                "windowMinutes": 300,
                "resetsAt": "2026-09-12T18:00:00Z"
              },
              "secondary": {
                "usedPercent": 71.0,
                "windowMinutes": 10080,
                "resetsAt": "2026-09-14T20:00:00Z"
              },
              "extraRateWindows": [
                {
                  "id": "opus",
                  "title": "Opus Allowance",
                  "window": {
                    "usedPercent": 18.0,
                    "resetsAt": "2026-09-12T18:00:00Z"
                  }
                }
              ],
              "accountEmail": "test@example.com",
              "updatedAt": "2026-09-12T15:30:00Z"
            },
            "source": "Web"
          }
        ]
        """.data(using: .utf8)!

        let responses = try JSONDecoder().decode([CodexBarResponse].self, from: json)
        XCTAssertEqual(responses.count, 1)

        let resp = responses[0]
        XCTAssertEqual(resp.provider, "claude")
        XCTAssertEqual(resp.source, "Web")

        let usage = resp.usage!
        XCTAssertEqual(usage.primary?.usedPercent, 49.0)
        XCTAssertEqual(usage.primary?.remainingPercent, 51.0)
        XCTAssertEqual(usage.secondary?.usedPercent, 71.0)
        XCTAssertEqual(usage.secondary?.remainingPercent, 29.0)
        XCTAssertEqual(usage.extraRateWindows?.count, 1)
        XCTAssertEqual(usage.extraRateWindows?[0].title, "Opus Allowance")
        XCTAssertEqual(usage.accountEmail, "test@example.com")

        let config = ProviderConfig(id: "claude", displayName: "Claude", cliName: "claude")
        let providerUsage = CodexBarCLIBridge.mapResponseToUsage(resp, config: config)
        XCTAssertEqual(providerUsage.sessionPercent, 49.0)
        XCTAssertEqual(providerUsage.primaryRemainingPercent, 51.0)
        XCTAssertEqual(providerUsage.weeklyPercent, 71.0)
        XCTAssertEqual(providerUsage.extraWindows.count, 1)
        XCTAssertEqual(providerUsage.extraWindows[0].remainingPercent, 82.0)
        XCTAssertEqual(providerUsage.accountEmail, "test@example.com")
        XCTAssertTrue(providerUsage.isConnected)
        XCTAssertNil(providerUsage.error)
    }

    func testDecodeErrorResponse() throws {
        let json = """
        [
          {
            "provider": "codex",
            "error": {
              "code": 1,
              "message": "Codex returned invalid data: codex app-server closed stdout",
              "kind": "provider"
            },
            "source": "auto"
          }
        ]
        """.data(using: .utf8)!

        let responses = try JSONDecoder().decode([CodexBarResponse].self, from: json)
        XCTAssertEqual(responses.count, 1)

        let resp = responses[0]
        XCTAssertEqual(resp.provider, "codex")
        XCTAssertEqual(resp.error?.code, 1)
        XCTAssertEqual(resp.error?.message, "Codex returned invalid data: codex app-server closed stdout")

        let config = ProviderConfig(id: "codex", displayName: "Codex", cliName: "codex")
        let usage = CodexBarCLIBridge.mapResponseToUsage(resp, config: config)
        XCTAssertEqual(usage.error, "Codex returned invalid data: codex app-server closed stdout")
        XCTAssertEqual(usage.statusDescription, "Error")
        XCTAssertFalse(usage.isConnected)
    }
}
