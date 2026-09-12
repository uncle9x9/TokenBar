import XCTest
@testable import TokenBarCore

@MainActor
final class OrbitSettingsTests: XCTestCase {
    private let keys = ["orbitProviderID", "orbitWindowID", "orbitIconEnabled", "enabledProviderIDs", "providerOrder", "tokenbar_migrated_from_upstream"]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in keys {
            saved[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.set(true, forKey: "tokenbar_migrated_from_upstream")
    }

    override func tearDown() {
        for key in keys {
            if let value = saved[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        saved = [:]
        super.tearDown()
    }

    func testDefaultsAndPersistence() {
        let store = UsageStore()
        XCTAssertEqual(store.orbitProviderID, "")
        XCTAssertEqual(store.orbitWindowID, "session")
        XCTAssertTrue(store.orbitIconEnabled)
        store.orbitProviderID = "claude"
        store.orbitWindowID = "weekly"
        store.orbitIconEnabled = false
        let restored = UsageStore()
        XCTAssertEqual(restored.orbitProviderID, "claude")
        XCTAssertEqual(restored.orbitWindowID, "weekly")
        XCTAssertFalse(restored.orbitIconEnabled)
    }

    func testProviderSelectionFollowsOrderAndEnabledState() {
        let store = UsageStore()
        store.enabledProviderIDs = ["claude", "codex"]
        store.providerOrder = ["codex", "claude"]
        XCTAssertEqual(store.orbitConfig?.id, "codex")
        store.orbitProviderID = "claude"
        XCTAssertEqual(store.orbitConfig?.id, "claude")
        store.usages.removeAll()
        XCTAssertEqual(store.orbitConfig?.id, "claude", "Missing usage must not switch providers")
        store.enabledProviderIDs = ["codex"]
        XCTAssertEqual(store.orbitConfig?.id, "codex")
        store.enabledProviderIDs = []
        XCTAssertNil(store.orbitConfig)
    }

    func testUnknownWindowLoadsSession() {
        UserDefaults.standard.set("unknown", forKey: "orbitWindowID")
        XCTAssertEqual(UsageStore().orbitWindowID, "session")
    }
}
