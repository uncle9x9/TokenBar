import AppKit
import SwiftUI

final class HoverTrackingView: NSView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    private var trackingAreaObj: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaObj {
            removeTrackingArea(existing)
        }
        let t = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(t)
        trackingAreaObj = t
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExit?()
    }
}

@MainActor
public final class StatusItemController: NSObject, NSPopoverDelegate {
    public static let shared = StatusItemController()

    private var statusItem: NSStatusItem!
    public private(set) var popover: NSPopover?
    private let store = UsageStore.shared
    private var settingsWindowController: NSWindowController?
    private var observationTask: Task<Void, Never>?

    // Hover & dismissal hysteresis tracking
    private var hoverTimer: Timer?
    private var dismissTimer: Timer?
    private var isMouseInButton = false
    private var isMouseInPopover = false
    public private(set) var isPinned = false

    private var buttonTrackingView: HoverTrackingView?
    private var popoverTrackingView: HoverTrackingView?

    public override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            let tracking = HoverTrackingView(frame: button.bounds)
            tracking.autoresizingMask = [.width, .height]
            tracking.onMouseEnter = { [weak self] in
                self?.handleButtonMouseEnter()
            }
            tracking.onMouseExit = { [weak self] in
                self?.handleButtonMouseExit()
            }
            button.addSubview(tracking)
            buttonTrackingView = tracking
        }

        setupPopover()
        updateDisplay()
        startObserving()
    }

    deinit {
        observationTask?.cancel()
        hoverTimer?.invalidate()
        dismissTimer?.invalidate()
    }

    public func currentPopoverSize() -> NSSize {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let maxAllowedHeight = max(380, screenHeight - 70)
        let sizing = ConsolidatedQuotaPanelView.calculateSizing(store: store, maxAvailableHeight: maxAllowedHeight)
        return NSSize(width: 360, height: sizing.targetHeight)
    }

    private func setupPopover() {
        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        p.delegate = self

        let panelView = ConsolidatedQuotaPanelView(
            store: store,
            onOpenSettings: { [weak self] in
                self?.openSettingsClicked()
            },
            onQuit: { [weak self] in
                self?.quitClicked()
            }
        )

        let initialSize = currentPopoverSize()
        p.contentSize = initialSize

        let hostingController = NSHostingController(rootView: panelView)
        hostingController.preferredContentSize = initialSize
        p.contentViewController = hostingController
        self.popover = p
    }

    private func attachPopoverTracking() {
        guard let contentView = popover?.contentViewController?.view else { return }
        if popoverTrackingView?.superview == contentView { return }

        let tracking = HoverTrackingView(frame: contentView.bounds)
        tracking.autoresizingMask = [.width, .height]
        tracking.onMouseEnter = { [weak self] in
            self?.handlePopoverMouseEnter()
        }
        tracking.onMouseExit = { [weak self] in
            self?.handlePopoverMouseExit()
        }
        contentView.addSubview(tracking, positioned: .below, relativeTo: nil)
        popoverTrackingView = tracking
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                self?.updateDisplay()
            }
        }
    }

    public func updateDisplay() {
        guard let button = statusItem.button else { return }

        let presentation = store.effectivePresentation
        let configs = store.enabledConfigs

        if configs.isEmpty {
            button.image = nil
            button.title = "TokenBar"
            button.toolTip = "No providers enabled"
            return
        }

        switch presentation {
        case .horizontal:
            // Upstream horizontal combined presentation (Level 0 glanceability)
            let providerDataList = configs.map { config -> StatusItemRenderer.ProviderData in
                let usage = store.usage(for: config.id)
                let ds = store.displaySetting(for: config.id)

                var rateWindows: [StatusItemRenderer.RateWindowData] = []
                if let s = usage.sessionPercent {
                    rateWindows.append(.init(
                        key: "session",
                        menuBarPrefix: nil,
                        usedPercent: s,
                        resetsAt: usage.sessionResetsAt,
                        windowMinutes: usage.sessionWindowMinutes,
                        settings: ds.settings(for: "session")
                    ))
                }
                if let w = usage.weeklyPercent {
                    rateWindows.append(.init(
                        key: "weekly",
                        menuBarPrefix: " W:",
                        usedPercent: w,
                        resetsAt: usage.weeklyResetsAt,
                        windowMinutes: usage.weeklyWindowMinutes,
                        settings: ds.settings(for: "weekly")
                    ))
                }
                for extra in usage.extraWindows {
                    let prefix = " \(extra.title.prefix(1)):"
                    rateWindows.append(.init(
                        key: extra.id,
                        menuBarPrefix: prefix,
                        usedPercent: extra.usedPercent,
                        resetsAt: extra.resetsAt,
                        windowMinutes: extra.windowMinutes,
                        settings: ds.settings(for: extra.id)
                    ))
                }

                return StatusItemRenderer.ProviderData(
                    providerID: config.id,
                    displayType: config.displayType,
                    balance: usage.balance,
                    showBalance: ds.showBalance,
                    rateWindows: rateWindows
                )
            }

            button.title = ""
            button.image = StatusItemRenderer.renderCombined(providers: providerDataList)
            button.toolTip = buildTooltip()

        case .vertical, .automatic:
            // Single TokenBar icon (compact footprint for notch avoidance)
            button.title = ""
            let icon = NSImage(systemSymbolName: "gauge.with.needle.fill", accessibilityDescription: "TokenBar")
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = buildTooltip()
        }

        if let pop = popover, pop.isShown {
            let targetSize = currentPopoverSize()
            if pop.contentSize != targetSize {
                pop.contentSize = targetSize
                pop.contentViewController?.preferredContentSize = targetSize
            }
        }
    }

    public func rebuildMenu() {
        updateDisplay()
    }

    // MARK: - Popover Presentation & Hover

    public func showConsolidatedPanel(pinned: Bool = false) {
        guard let button = statusItem.button, let pop = popover else { return }

        let targetSize = currentPopoverSize()
        pop.contentSize = targetSize
        pop.contentViewController?.preferredContentSize = targetSize

        if pop.isShown {
            if pinned { isPinned = true }
            return
        }

        isPinned = pinned
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        attachPopoverTracking()
    }

    public func hideConsolidatedPanel(force: Bool = false) {
        if force { isPinned = false }
        guard let pop = popover, pop.isShown else { return }
        if isPinned && !force { return }
        isPinned = false
        pop.performClose(nil)
    }

    public func popoverDidClose(_ notification: Notification) {
        isPinned = false
        isMouseInButton = false
        isMouseInPopover = false
        hoverTimer?.invalidate()
        hoverTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    // MARK: - Mouse Event Handlers

    private func handleButtonMouseEnter() {
        isMouseInButton = true
        dismissTimer?.invalidate()
        dismissTimer = nil

        // 120ms debounce so rapid pointer movement across status bar does not spuriously trigger
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isMouseInButton else { return }
                self.showConsolidatedPanel(pinned: false)
            }
        }
    }

    private func handleButtonMouseExit() {
        isMouseInButton = false
        hoverTimer?.invalidate()
        hoverTimer = nil
        scheduleDismissal()
    }

    private func handlePopoverMouseEnter() {
        isMouseInPopover = true
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    private func handlePopoverMouseExit() {
        isMouseInPopover = false
        scheduleDismissal()
    }

    private func scheduleDismissal() {
        guard !isPinned else { return }
        dismissTimer?.invalidate()
        // 300ms hysteresis buffer allows seamless movement between status item and popover
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.isMouseInButton && !self.isMouseInPopover && !self.isPinned {
                    self.hideConsolidatedPanel(force: true)
                }
            }
        }
    }

    // MARK: - Click Handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu(from: sender, with: event)
            return
        }

        // Left click toggles pinned panel
        if let pop = popover, pop.isShown {
            if isPinned {
                hideConsolidatedPanel(force: true)
            } else {
                isPinned = true
            }
        } else {
            showConsolidatedPanel(pinned: true)
        }
    }

    private func showContextMenu(from button: NSStatusBarButton, with event: NSEvent) {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(
            title: store.isRefreshing ? "Refreshing Providers…" : "Refresh All",
            action: #selector(refreshAllClicked),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        refreshItem.isEnabled = !store.isRefreshing
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit TokenBar",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    private func buildTooltip() -> String {
        let asAbsolute = UserDefaults.standard.bool(forKey: "resetTimeAsAbsolute")
        var lines: [String] = []
        for config in store.enabledConfigs {
            let usage = store.usage(for: config.id)
            var line = config.displayName + ": "
            if let s = usage.sessionPercent {
                line += "\(Int(s))%"
                if let w = usage.weeklyPercent { line += " · W:\(Int(w))%" }
                if let reset = ResetTimeFormatter.resetLine(date: usage.sessionResetsAt, asAbsolute: asAbsolute) {
                    line += " · \(reset)"
                }
            } else if let b = usage.balance {
                line += b
            } else if let err = usage.error {
                line += err
            } else {
                line += "--"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Actions

    @objc public func refreshAllClicked() {
        Task {
            await store.refreshAll()
            updateDisplay()
        }
    }

    @objc public func openSettingsClicked() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "TokenBar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: SettingsTab.defaultWidth, height: 480)
        window.isReleasedWhenClosed = false
        if !window.setFrameUsingName("TokenBar.SettingsWindow") {
            window.setContentSize(NSSize(width: SettingsTab.defaultWidth, height: SettingsTab.windowHeight))
            window.center()
        }
        window.setFrameAutosaveName("TokenBar.SettingsWindow")

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func quitClicked() {
        NSApp.terminate(nil)
    }
}
