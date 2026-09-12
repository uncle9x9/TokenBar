import AppKit
import SwiftUI

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    public static let shared = StatusItemController()

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let store = UsageStore.shared
    private var settingsWindowController: NSWindowController?
    private var observationTask: Task<Void, Never>?

    public override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        updateDisplay()
        rebuildMenu()
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                self?.updateDisplay()
            }
        }
    }

    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
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
            // Upstream horizontal combined presentation
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
            // Single TokenBar icon
            button.title = ""
            let icon = NSImage(systemSymbolName: "gauge.with.needle.fill", accessibilityDescription: "TokenBar")
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = buildTooltip()
        }
    }

    public func rebuildMenu() {
        menu.removeAllItems()

        let configs = store.enabledConfigs
        let presentation = store.effectivePresentation

        if presentation == .vertical {
            // Header item
            let headerItem = NSMenuItem(title: "TokenBar", action: nil, keyEquivalent: "")
            let titleFont = NSFont.systemFont(ofSize: 13, weight: .bold)
            headerItem.attributedTitle = NSAttributedString(string: "TokenBar", attributes: [.font: titleFont])
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            menu.addItem(.separator())
        }

        if configs.isEmpty {
            let emptyItem = NSMenuItem(title: "No providers enabled", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for config in configs {
                let usage = store.usage(for: config.id)
                let item = makeProviderMenuItem(config: config, usage: usage)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Persistent Actions
        let refreshItem = NSMenuItem(
            title: store.isRefreshing ? "Refreshing Providers…" : "Refresh All",
            action: #selector(refreshAllClicked),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        refreshItem.isEnabled = !store.isRefreshing
        if let icon = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil) {
            icon.isTemplate = true
            refreshItem.image = icon
        }
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = self
        if let icon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) {
            icon.isTemplate = true
            settingsItem.image = icon
        }
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit TokenBar",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeProviderMenuItem(config: ProviderConfig, usage: ProviderUsage) -> NSMenuItem {
        let quotaText: String
        if usage.error != nil {
            quotaText = "Err"
        } else if let s = usage.sessionPercent {
            quotaText = "\(Int(s))%"
        } else if let b = usage.balance {
            quotaText = b
        } else {
            quotaText = "--"
        }

        let item = NSMenuItem()
        if let icon = ProviderIcons.icon(for: config.id, size: 16) {
            item.image = icon
        } else {
            item.image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
        }

        // Use native paragraph style with tab stop for clean right-aligned quota display
        let pStyle = NSMutableParagraphStyle()
        let tab = NSTextTab(textAlignment: .right, location: 190, options: [:])
        pStyle.tabStops = [tab]

        let titleStr = "\(config.displayName)\t\(quotaText)"
        let attrTitle = NSMutableAttributedString(string: titleStr, attributes: [
            .font: NSFont.menuFont(ofSize: 14),
            .paragraphStyle: pStyle
        ])
        item.attributedTitle = attrTitle
        item.representedObject = config.id
        item.target = self
        item.action = #selector(providerItemClicked(_:))

        // Native detail submenu
        let detailSubmenu = NSMenu()
        detailSubmenu.autoenablesItems = false

        let cardView = ProviderDetailCardView(config: config, usage: usage, width: 280)
        let hostingView = NSHostingView(rootView: cardView)
        hostingView.frame.size = hostingView.fittingSize

        let cardMenuItem = NSMenuItem()
        cardMenuItem.view = hostingView
        cardMenuItem.isEnabled = false
        detailSubmenu.addItem(cardMenuItem)

        detailSubmenu.addItem(.separator())

        let refreshSingleItem = NSMenuItem(
            title: "Refresh \(config.displayName)",
            action: #selector(refreshSingleProviderClicked(_:)),
            keyEquivalent: ""
        )
        refreshSingleItem.representedObject = config.id
        refreshSingleItem.target = self
        if let icon = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil) {
            icon.isTemplate = true
            refreshSingleItem.image = icon
        }
        detailSubmenu.addItem(refreshSingleItem)

        item.submenu = detailSubmenu
        return item
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

            for extra in usage.extraWindows {
                lines.append("  \(extra.title): \(Int(extra.usedPercent))%")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func refreshAllClicked() {
        Task {
            await store.refreshAll()
            updateDisplay()
            rebuildMenu()
        }
    }

    @objc private func refreshSingleProviderClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Task {
            await store.refreshProvider(id: id)
            updateDisplay()
            rebuildMenu()
        }
    }

    @objc private func providerItemClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Task {
            await store.refreshProvider(id: id)
            updateDisplay()
            rebuildMenu()
        }
    }

    @objc private func openSettingsClicked() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "TokenBar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
