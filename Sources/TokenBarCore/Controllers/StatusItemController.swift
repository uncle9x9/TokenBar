import AppKit
import SwiftUI

final class HoverTrackingView: NSView {
    var onMouseEnter: (() -> Void)?
    var onMouseExit: (() -> Void)?
    private var trackingAreaObj: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return nil to pass through all mouse clicks to NSStatusBarButton beneath
        return nil
    }

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

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

final class FirstMouseHostingController<Content: View>: NSHostingController<Content> {
    override init(rootView: Content) {
        super.init(rootView: rootView)
        let customView = FirstMouseHostingView(rootView: rootView)
        customView.autoresizingMask = [.width, .height]
        self.view = customView
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
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
    private var appearanceObservation: NSKeyValueObservation?

    // Hover & dismissal hysteresis tracking
    private var hoverTimer: Timer?
    private var dismissTimer: Timer?
    private var isMouseInButton = false
    private var isMouseInPopover = false
    public private(set) var isPinned = false

    // Loading animation tracking (counter-clockwise rotation during refresh/loading)
    private var loadingAnimationTimer: Timer?
    public private(set) var loadingRotationAngle: CGFloat = 0

    private var buttonTrackingView: HoverTrackingView?

    public override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateDisplay() }
            }
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

        store.onRefreshingChanged = { [weak self] isRefreshing in
            Task { @MainActor in
                if isRefreshing {
                    self?.startLoadingAnimation()
                } else {
                    self?.stopLoadingAnimation()
                }
            }
        }

        setupPopover()
        if store.isRefreshing || store.lastRefreshTime == nil {
            startLoadingAnimation()
        }
        updateDisplay()
        startObserving()
    }

    deinit {
        observationTask?.cancel()
        loadingAnimationTimer?.invalidate()
        hoverTimer?.invalidate()
        dismissTimer?.invalidate()
    }

    public func startLoadingAnimation() {
        guard loadingAnimationTimer == nil else { return }
        // 20 fps: 0.05s interval, +9 degrees per frame = 2.0s per 360 degree counter-clockwise revolution
        loadingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.loadingRotationAngle = (self.loadingRotationAngle + 9.0).truncatingRemainder(dividingBy: 360.0)
                self.updateDisplay()
            }
        }
    }

    public func stopLoadingAnimation() {
        loadingAnimationTimer?.invalidate()
        loadingAnimationTimer = nil
        loadingRotationAngle = 0
        updateDisplay()
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
            },
            onHoverChanged: { [weak self] isHovered in
                if isHovered {
                    self?.handlePopoverMouseEnter()
                } else {
                    self?.handlePopoverMouseExit()
                }
            }
        )

        let initialSize = currentPopoverSize()
        p.contentSize = initialSize

        let hostingController = FirstMouseHostingController(rootView: panelView)
        hostingController.preferredContentSize = initialSize
        p.contentViewController = hostingController
        self.popover = p
    }

    private func startObserving() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                self?.updateDisplay()
            }
        }
    }

    public func updateDisplay() {
        guard let button = statusItem?.button else { return }

        let presentation = store.effectivePresentation
        let configs = store.enabledConfigs
        let now = Date()
        let config = store.orbitConfig
        let state = QuotaClockState(usage: config.map { store.usage(for: $0.id) }, windowID: store.orbitWindowID, now: now)
        let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let isInitialLoad = store.lastRefreshTime == nil && store.isRefreshing
        let clock = QuotaClockIcon.render(state: state, dark: dark, rotationAngle: loadingRotationAngle)
        let clockDescription = state.description(provider: config?.displayName ?? "TokenBar",
                                                 window: store.orbitWindowID == "weekly" ? "Weekly" : "Session", now: now)

        if configs.isEmpty {
            button.image = clock
            button.title = ""
            button.toolTip = "No providers enabled"
            return
        }

        if isInitialLoad && presentation != .vertical {
            button.title = ""
            button.image = clock
            button.toolTip = "TokenBar: Loading quotas…"
            return
        }

        switch presentation {
        case .horizontal:
            // Upstream horizontal combined presentation (Level 0 glanceability)
            let providerDataList = configs.map { buildProviderData(for: $0) }
            button.title = ""
            button.image = StatusItemRenderer.renderCombined(providers: providerDataList, overflowCount: 0)
            button.toolTip = buildTooltip()

        case .hybrid:
            // Hybrid / Overflow: keep top N in menu bar, reveal all on hover
            let maxVisible = store.maxVisibleInMenuBar
            let visibleConfigs = Array(configs.prefix(maxVisible))
            let overflowCount = max(0, configs.count - maxVisible)

            let providerDataList = visibleConfigs.map { buildProviderData(for: $0) }
            button.title = ""
            button.image = StatusItemRenderer.renderCombined(providers: providerDataList, overflowCount: overflowCount)
            button.toolTip = buildTooltip()

        case .vertical, .automatic:
            // Single TokenBar icon (compact footprint for notch avoidance)
            button.title = ""
            button.image = clock
            button.toolTip = clockDescription + "\n" + buildTooltip()
        }

        if store.orbitIconEnabled && (presentation == .horizontal || presentation == .hybrid), let details = button.image {
            button.image = QuotaClockIcon.combining(clock: clock, details: details, dark: dark)
            button.toolTip = clockDescription + "\n" + buildTooltip()
        }
        button.setAccessibilityLabel(button.toolTip)

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
        if let window = pop.contentViewController?.view.window {
            window.makeKey()
        }
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

    private func buildProviderData(for config: ProviderConfig) -> StatusItemRenderer.ProviderData {
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

    private func buildTooltip() -> String {
        let asAbsolute = UserDefaults.standard.bool(forKey: "resetTimeAsAbsolute")
        let countdown5h = UserDefaults.standard.object(forKey: "countdownForFiveHourLimits") as? Bool ?? true
        var lines: [String] = []
        for config in store.enabledConfigs {
            let usage = store.usage(for: config.id)
            var line = config.displayName + ": "
            if let s = usage.sessionPercent {
                line += "\(Int(s))%"
                if let w = usage.weeklyPercent { line += " · W:\(Int(w))%" }
                let is5h = countdown5h && (config.id == "claude" || config.id == "codex" || usage.sessionWindowMinutes == 300)
                if let reset = ResetTimeFormatter.resetLine(date: usage.sessionResetsAt, asAbsolute: is5h ? false : asAbsolute) {
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
        hideConsolidatedPanel(force: true)

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
