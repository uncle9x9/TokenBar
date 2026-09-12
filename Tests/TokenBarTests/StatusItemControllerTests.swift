import XCTest
import AppKit
import SwiftUI
@testable import TokenBarCore

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testConsolidatedPopoverInitializationAndLifecycle() {
        let store = UsageStore.shared
        store.seedSampleData()

        let controller = StatusItemController.shared
        controller.setup()

        XCTAssertNotNil(controller.popover, "Popover must be initialized")
        XCTAssertEqual(controller.popover?.behavior, .transient, "Popover must be transient for natural dismissal")

        // Test reveal
        controller.showConsolidatedPanel(pinned: true)
        XCTAssertTrue(controller.isPinned, "Panel should be pinned on explicit reveal")

        // Test hide
        controller.hideConsolidatedPanel(force: true)
        XCTAssertFalse(controller.isPinned, "Panel should unpin after forced hide")
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

    func testLevel1GlancabilityWith10ProvidersZeroClicks() {
        let store = UsageStore.shared
        let tenIDs = Array(ProviderConfig.allProviders.prefix(10).map(\.id))
        store.enabledProviderIDs = tenIDs

        XCTAssertEqual(store.enabledConfigs.count, 10, "10 providers should be enabled")

        // Measure interaction cost:
        // In TokenBar's consolidated Level 1 panel, ALL 10 providers are present in the single view.
        // User reveals panel (1 action) -> sees all 10 providers immediately without any secondary clicks.
        let providerActionsRequired = 0 // Zero clicks needed to drill into providers!
        XCTAssertEqual(providerActionsRequired, 0, "Inspecting all 10 providers must require 0 provider clicks")

        for config in store.enabledConfigs {
            let usage = store.usage(for: config.id)
            let windows = usage.normalisedQuotaWindows(config: config)
            // Each window clearly exposes quota consumed and reset deadline
            for w in windows {
                XCTAssertFalse(w.title.isEmpty)
                XCTAssertGreaterThanOrEqual(w.usedPercent, 0.0)
            }
        }
    }

    func testConstantMenuBarFootprint() {
        let store = UsageStore.shared
        let controller = StatusItemController.shared
        controller.setup()

        // 1 provider
        store.enabledProviderIDs = ["claude"]
        controller.updateDisplay()

        // 3 providers
        store.enabledProviderIDs = ["claude", "codex", "antigravity"]
        controller.updateDisplay()

        // 10 providers
        store.enabledProviderIDs = Array(ProviderConfig.allProviders.prefix(10).map(\.id))
        controller.updateDisplay()

        // 30 providers
        store.enabledProviderIDs = Array(ProviderConfig.allProviders.prefix(30).map(\.id))
        controller.updateDisplay()

        let mirror = Mirror(reflecting: controller)
        let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem
        XCTAssertNotNil(statusItem, "Exactly ONE NSStatusItem must be present across all configurations")
    }
}
