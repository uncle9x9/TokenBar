import XCTest
import Foundation
@testable import TokenBarCore

final class ConfigurationMigratorTests: XCTestCase {
    func testMigrationDetectionAndImport() {
        let (source, available) = ConfigurationMigrator.detectMigrationSource()
        XCTAssertTrue(available, "Expected to detect existing CodexBarMenuBar preferences on this Mac")
        XCTAssertTrue(source.contains("CodexBarMenuBar"), "Expected source to be CodexBarMenuBar")

        guard let result = ConfigurationMigrator.performMigration() else {
            XCTFail("performMigration should return a valid MigrationResult")
            return
        }

        XCTAssertFalse(result.enabledProviderIDs.isEmpty, "Enabled provider IDs should not be empty")
        XCTAssertTrue(result.enabledProviderIDs.contains("claude"), "Expected claude to be enabled")
        XCTAssertTrue(result.enabledProviderIDs.contains("codex"), "Expected codex to be enabled")
        XCTAssertTrue(result.enabledProviderIDs.contains("antigravity"), "Expected antigravity to be enabled")

        if let interval = result.refreshInterval {
            XCTAssertEqual(interval, 300.0, "Expected 300s refresh interval from existing preferences")
        }

        if let resetAbs = result.resetTimeAsAbsolute {
            XCTAssertTrue(resetAbs, "Expected resetTimeAsAbsolute to be true from existing preferences")
        }
    }

    @MainActor
    func testUsageStoreMigrationApplication() {
        let store = UsageStore()
        let result = store.migrateFromPreviousConfig()

        XCTAssertNotNil(result, "Expected migration to succeed")
        XCTAssertEqual(store.enabledProviderIDs, ["claude", "codex", "antigravity"])
        XCTAssertEqual(store.refreshInterval, 300.0)
        XCTAssertTrue(store.resetTimeAsAbsolute)

        // Verify ordered enabled configs matches providerOrder
        let configs = store.enabledConfigs
        XCTAssertEqual(configs.count, 3)
        XCTAssertEqual(configs[0].id, "claude")
        XCTAssertEqual(configs[1].id, "codex")
        XCTAssertEqual(configs[2].id, "antigravity")
    }
}
