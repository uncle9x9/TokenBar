import XCTest
import AppKit
import SwiftUI
@testable import TokenBarCore

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testMenuHierarchyAndSubmenus() {
        let store = UsageStore.shared
        store.presentation = .vertical
        store.seedSampleData()

        let controller = StatusItemController.shared
        controller.setup()
        controller.rebuildMenu()

        let mirror = Mirror(reflecting: controller)
        guard let menu = mirror.children.first(where: { $0.label == "menu" })?.value as? NSMenu else {
            XCTFail("Could not access StatusItemController.menu")
            return
        }

        XCTAssertFalse(menu.items.isEmpty, "Root menu should not be empty")

        // 1. First item in vertical mode is TokenBar header
        let headerItem = menu.items.first
        XCTAssertEqual(headerItem?.title, "TokenBar")

        // 2. Locate provider items
        let providerItems = menu.items.filter { item in
            guard let id = item.representedObject as? String else { return false }
            return ProviderConfig.byID[id] != nil
        }

        XCTAssertEqual(providerItems.count, store.enabledConfigs.count, "Each enabled provider must have an item")

        // 3. Verify that EVERY provider row has a native macOS detail submenu attached
        for item in providerItems {
            let providerID = item.representedObject as! String
            guard let submenu = item.submenu else {
                XCTFail("Provider \(providerID) must have an attached detail submenu")
                continue
            }

            // Submenu contains detail card + separator + refresh item
            XCTAssertGreaterThanOrEqual(submenu.items.count, 2, "Submenu must contain detail card and refresh item")
            let detailItem = submenu.items[0]
            XCTAssertNotNil(detailItem.view, "Detail item must host a custom ProviderDetailCardView")
            XCTAssertFalse(detailItem.isEnabled, "Detail item must be disabled so clicking does not close menu unintentionally")

            let refreshItem = submenu.items.last
            XCTAssertTrue(refreshItem?.title.contains("Refresh") == true, "Submenu must have refresh action")
        }

        // 4. Verify persistent action items exist
        let titles = menu.items.map(\.title)
        XCTAssertTrue(titles.contains(where: { $0.contains("Refresh") }), "Menu must have Refresh action")
        XCTAssertTrue(titles.contains("Settings…"), "Menu must have Settings action")
        XCTAssertTrue(titles.contains("Quit TokenBar"), "Menu must have Quit action")
    }

    func testHorizontalPresentationSwitch() {
        let store = UsageStore.shared
        store.presentation = .horizontal
        XCTAssertEqual(store.effectivePresentation, .horizontal)

        let controller = StatusItemController.shared
        controller.setup()
        controller.updateDisplay()

        let mirror = Mirror(reflecting: controller)
        let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem
        XCTAssertNotNil(statusItem?.button?.image, "Horizontal mode must render combined status item image")
    }

    func testConstantMenuBarFootprint() {
        let store = UsageStore.shared
        let controller = StatusItemController.shared
        controller.setup()

        store.enabledProviderIDs = ["claude", "codex"]
        controller.rebuildMenu()

        store.enabledProviderIDs = ProviderConfig.allProviders.map(\.id)
        controller.rebuildMenu()

        let mirror = Mirror(reflecting: controller)
        let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem
        XCTAssertNotNil(statusItem, "Single NSStatusItem must be present")
    }
}
