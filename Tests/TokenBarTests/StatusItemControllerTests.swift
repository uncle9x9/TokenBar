import XCTest
import AppKit
import SwiftUI
@testable import TokenBarCore

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testMenuHierarchyAndSubmenus() {
        let store = UsageStore.shared
        store.seedSampleData()

        let controller = StatusItemController.shared
        controller.setup()
        controller.rebuildMenu()

        // Access the private or reflection status item/menu
        // Test menu items structure
        let mirror = Mirror(reflecting: controller)
        guard let menu = mirror.children.first(where: { $0.label == "menu" })?.value as? NSMenu else {
            XCTFail("Could not access StatusItemController.menu")
            return
        }

        XCTAssertFalse(menu.items.isEmpty, "Root menu should not be empty")

        // 1. First item should be header card
        let headerItem = menu.items.first
        XCTAssertNotNil(headerItem?.view, "Header item must have a custom view")

        // 2. Locate provider items (items that have representedObject set to a provider ID)
        let providerItems = menu.items.filter { item in
            guard let id = item.representedObject as? String else { return false }
            return ProviderConfig.byID[id] != nil
        }

        XCTAssertEqual(providerItems.count, store.enabledConfigs.count, "Each enabled provider must have an overview row")

        // 3. Verify that EVERY provider row has a native macOS detail submenu attached!
        for item in providerItems {
            let providerID = item.representedObject as! String
            guard let submenu = item.submenu else {
                XCTFail("Provider \(providerID) must have an attached detail submenu")
                continue
            }

            XCTAssertEqual(submenu.items.count, 1, "Submenu must contain the detail card item")
            let detailItem = submenu.items[0]
            XCTAssertNotNil(detailItem.view, "Detail item must host a custom ProviderDetailCardView")
            XCTAssertFalse(detailItem.isEnabled, "Detail item must be disabled so clicking does not close menu unintentionally")
        }

        // 4. Verify persistent action items exist
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains(where: { $0.contains("Refresh") }), "Menu must have Refresh action")
        XCTAssertTrue(titles.contains("Settings…"), "Menu must have Settings action")
        XCTAssertTrue(titles.contains("Quit TokenBar"), "Menu must have Quit action")
    }

    func testConstantMenuBarFootprint() {
        let store = UsageStore.shared
        let controller = StatusItemController.shared
        controller.setup()

        // Whether 5 providers or 15 providers are enabled, exactly ONE NSStatusItem is maintained
        store.enabledProviderIDs = ["claude", "codex"]
        controller.rebuildMenu()

        store.enabledProviderIDs = ProviderConfig.allProviders.map(\.id)
        controller.rebuildMenu()

        let mirror = Mirror(reflecting: controller)
        let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem
        XCTAssertNotNil(statusItem, "Single NSStatusItem must be present")
    }
}
