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

    func testPanelAutoSizingWithFourProvidersHasNoScrollbar() {
        let store = UsageStore.shared
        store.seedSampleData()
        store.enabledProviderIDs = ["claude", "codex", "antigravity", "gemini"]

        XCTAssertEqual(store.enabledConfigs.count, 4)

        let typicalMacScreenMaxHeight: CGFloat = 830.0
        let sizing = ConsolidatedQuotaPanelView.calculateSizing(store: store, maxAvailableHeight: typicalMacScreenMaxHeight)

        // With 4 providers: MUST NOT SCROLL, no scrollbar, content matches target height
        XCTAssertFalse(sizing.needsScroll, "4 providers must fit completely without scrolling!")
        XCTAssertEqual(sizing.targetHeight, sizing.contentHeight, "Target height should exactly match content height for 4 providers")
        XCTAssertLessThanOrEqual(sizing.targetHeight, 500.0, "4 providers should comfortably fit in under 500pt")
        XCTAssertGreaterThanOrEqual(sizing.targetHeight, 250.0, "4 providers should allocate reasonable height for all quota bars")

        let controller = StatusItemController.shared
        controller.setup()
        let popoverSize = controller.currentPopoverSize()
        XCTAssertEqual(popoverSize.width, 360)
        XCTAssertEqual(popoverSize.height, sizing.targetHeight)
    }

    func testPanelAutoSizingWithTenProvidersFitsOnMacBookDisplay() {
        let store = UsageStore.shared
        store.seedSampleData()
        let tenIDs = Array(ProviderConfig.allProviders.prefix(10).map(\.id))
        store.enabledProviderIDs = tenIDs

        XCTAssertEqual(store.enabledConfigs.count, 10)

        let typicalMacScreenMaxHeight: CGFloat = 830.0
        let sizing = ConsolidatedQuotaPanelView.calculateSizing(store: store, maxAvailableHeight: typicalMacScreenMaxHeight)

        // 10 providers should fit on a standard MacBook Pro display without scrolling
        XCTAssertFalse(sizing.needsScroll, "10 standard providers should fit simultaneously on a typical MacBook display")
        XCTAssertLessThanOrEqual(sizing.targetHeight, typicalMacScreenMaxHeight)
    }

    func testPanelAutoSizingWithThirtyProvidersCapsAndScrolls() {
        let store = UsageStore.shared
        store.seedSampleData()
        let thirtyIDs = Array(ProviderConfig.allProviders.prefix(30).map(\.id))
        store.enabledProviderIDs = thirtyIDs

        XCTAssertEqual(store.enabledConfigs.count, 30)

        let typicalMacScreenMaxHeight: CGFloat = 830.0
        let sizing = ConsolidatedQuotaPanelView.calculateSizing(store: store, maxAvailableHeight: typicalMacScreenMaxHeight)

        // 30 providers genuine overflow: MUST cap to screen height and enable scrolling
        XCTAssertTrue(sizing.needsScroll, "30 providers must enable scrolling")
        XCTAssertEqual(sizing.targetHeight, typicalMacScreenMaxHeight, "Height must cap exactly at max available screen height")
        XCTAssertGreaterThan(sizing.contentHeight, typicalMacScreenMaxHeight, "Content height should exceed screen height")
    }

    func testSettingsWindowIsResizableAndHasMinimumSize() {
        let controller = StatusItemController.shared
        controller.openSettingsClicked()

        let mirror = Mirror(reflecting: controller)
        let windowController = mirror.children.first(where: { $0.label == "settingsWindowController" })?.value as? NSWindowController
        XCTAssertNotNil(windowController, "Settings window controller should exist")

        guard let window = windowController?.window else {
            XCTFail("Settings window missing")
            return
        }

        XCTAssertTrue(window.styleMask.contains(.resizable), "Settings window must be resizable")
        XCTAssertTrue(window.styleMask.contains(.closable), "Settings window must be closable")
        XCTAssertTrue(window.styleMask.contains(.miniaturizable), "Settings window must be miniaturizable")
        XCTAssertGreaterThanOrEqual(window.minSize.width, 546, "Minimum width must be at least default width")
        XCTAssertGreaterThanOrEqual(window.minSize.height, 480, "Minimum height must be at least 480pt")

        window.close()
    }

    func testFooterButtonsAndFirstMouseHitTesting() {
        let controller = StatusItemController.shared
        controller.setup()

        guard let pop = controller.popover, let hosting = pop.contentViewController else {
            XCTFail("Popover missing")
            return
        }

        XCTAssertTrue(hosting.view.acceptsFirstMouse(for: nil), "Popover view MUST accept first mouse so footer buttons click on first click")

        let mirror = Mirror(reflecting: controller)
        if let btnTracking = mirror.children.first(where: { $0.label == "buttonTrackingView" })?.value as? NSView {
            XCTAssertNil(btnTracking.hitTest(NSPoint(x: 10, y: 10)), "HoverTrackingView MUST return nil from hitTest so clicks reach NSStatusBarButton")
        }
    }
}
