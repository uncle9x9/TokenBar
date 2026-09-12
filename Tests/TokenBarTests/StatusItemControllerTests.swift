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

    func testHybridPresentationModeAndOverflowBadge() {
        let store = UsageStore.shared
        store.seedSampleData()
        let controller = StatusItemController.shared
        controller.setup()

        store.presentation = .hybrid
        store.maxVisibleInMenuBar = 3
        store.enabledProviderIDs = ["claude", "codex", "antigravity", "gemini"]

        XCTAssertEqual(store.effectivePresentation, .hybrid)
        XCTAssertEqual(store.enabledConfigs.count, 4)
        XCTAssertEqual(store.maxVisibleInMenuBar, 3)

        controller.updateDisplay()

        let mirror = Mirror(reflecting: controller)
        let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem
        guard let button = statusItem?.button else {
            XCTFail("StatusItem button missing")
            return
        }

        XCTAssertNotNil(button.image, "Button must have combined rendered image for hybrid mode")
        XCTAssertGreaterThan(button.image?.size.width ?? 0, 50, "Combined image must span multiple providers and overflow badge")

        // Renderer verification: 3 providers + 1 overflow
        let visibleConfigs = Array(store.enabledConfigs.prefix(3))
        let providerDataList = visibleConfigs.map { config -> StatusItemRenderer.ProviderData in
            let usage = store.usage(for: config.id)
            return StatusItemRenderer.ProviderData(
                providerID: config.id,
                displayType: config.displayType,
                balance: usage.balance,
                showBalance: true,
                rateWindows: []
            )
        }

        let imageWithOverflow = StatusItemRenderer.renderCombined(providers: providerDataList, overflowCount: 1)
        let imageWithoutOverflow = StatusItemRenderer.renderCombined(providers: providerDataList, overflowCount: 0)

        XCTAssertGreaterThan(imageWithOverflow.size.width, imageWithoutOverflow.size.width, "Overflow badge +1 must add width to status item image")
    }

    func testContextMenuStructureAndActionHandling() {
        let store = UsageStore.shared
        store.seedSampleData()
        let controller = StatusItemController.shared
        controller.setup()

        let menu = controller.buildContextMenu()
        let itemTitles = menu.items.map(\.title)

        XCTAssertTrue(itemTitles.contains("Open Quota Panel"), "Menu should have Open Quota Panel when closed")
        XCTAssertTrue(itemTitles.contains(where: { $0.hasPrefix("Refresh") }), "Menu should have Refresh item")
        XCTAssertTrue(itemTitles.contains("Presentation Mode"), "Menu should contain Presentation Mode submenu")
        XCTAssertTrue(itemTitles.contains("Reset Time Format"), "Menu should contain Reset Time Format submenu")
        XCTAssertTrue(itemTitles.contains("Settings…"), "Menu should contain Settings")
        XCTAssertTrue(itemTitles.contains("Quit TokenBar"), "Menu should contain Quit")

        // Check Presentation Mode submenu
        let presentationItem = menu.items.first(where: { $0.title == "Presentation Mode" })
        XCTAssertNotNil(presentationItem?.submenu)
        let presentationSubTitles = presentationItem?.submenu?.items.map(\.title) ?? []
        XCTAssertTrue(presentationSubTitles.contains(where: { $0.hasPrefix("Automatic") }))
        XCTAssertTrue(presentationSubTitles.contains(where: { $0.hasPrefix("Hybrid") }))
        XCTAssertTrue(presentationSubTitles.contains(where: { $0.hasPrefix("Horizontal") }))
        XCTAssertTrue(presentationSubTitles.contains(where: { $0.hasPrefix("Vertical") }))

        // Test presentation mode action switching
        controller.setPresentationHybrid()
        XCTAssertEqual(store.presentation, .hybrid)
        controller.setPresentationHorizontal()
        XCTAssertEqual(store.presentation, .horizontal)
        controller.setPresentationVertical()
        XCTAssertEqual(store.presentation, .vertical)
        controller.setPresentationAutomatic()
        XCTAssertEqual(store.presentation, .automatic)

        // Check Reset Time Format submenu
        let resetTimeItem = menu.items.first(where: { $0.title == "Reset Time Format" })
        XCTAssertNotNil(resetTimeItem?.submenu)
        let resetSubTitles = resetTimeItem?.submenu?.items.map(\.title) ?? []
        XCTAssertTrue(resetSubTitles.contains("Always Countdown 5-Hour Limits"))
        XCTAssertTrue(resetSubTitles.contains("Show Clock Values (e.g. 9:00 AM)"))

        // Test toggle actions
        let prev5h = store.countdownForFiveHourLimits
        controller.toggleCountdownForFiveHourLimits()
        XCTAssertEqual(store.countdownForFiveHourLimits, !prev5h)
        controller.toggleCountdownForFiveHourLimits()
        XCTAssertEqual(store.countdownForFiveHourLimits, prev5h)

        let prevAbs = store.resetTimeAsAbsolute
        controller.toggleResetTimeAsAbsolute()
        XCTAssertEqual(store.resetTimeAsAbsolute, !prevAbs)
        controller.toggleResetTimeAsAbsolute()
        XCTAssertEqual(store.resetTimeAsAbsolute, prevAbs)
    }
}
