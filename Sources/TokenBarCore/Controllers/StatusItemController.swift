import AppKit
import SwiftUI

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    public static let shared = StatusItemController()

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let store = UsageStore.shared
    private var settingsWindowController: NSWindowController?

    public override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "gauge.with.needle.fill", accessibilityDescription: "TokenBar")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeft
        }

        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        rebuildMenu()
    }

    public func menuWillOpen(_ menu: NSMenu) {
        // Rebuild menu with latest store snapshot whenever opened
        rebuildMenu()
    }

    public func rebuildMenu() {
        menu.removeAllItems()

        let menuWidth: CGFloat = 270

        // 1. Header Card
        let headerView = MenuHeaderView(store: store, width: menuWidth)
        let headerItem = makeCustomMenuItem(view: headerView, width: menuWidth)
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // 2. Enabled Provider Rows
        let configs = store.enabledConfigs
        if configs.isEmpty {
            let emptyItem = NSMenuItem(title: "No providers enabled", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for config in configs {
                let usage = store.usage(for: config.id)
                let rowItem = makeProviderRowMenuItem(config: config, usage: usage, width: menuWidth)
                menu.addItem(rowItem)
            }
        }

        menu.addItem(.separator())

        // 3. Persistent Actions
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

        let sampleItem = NSMenuItem(
            title: "Load Sample Data",
            action: #selector(loadSampleDataClicked),
            keyEquivalent: "d"
        )
        sampleItem.keyEquivalentModifierMask = [.command, .option]
        sampleItem.target = self
        menu.addItem(sampleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit TokenBar",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeProviderRowMenuItem(config: ProviderConfig, usage: ProviderUsage, width: CGFloat) -> NSMenuItem {
        let rowView = ProviderOverviewRowView(config: config, usage: usage, width: width)
        let hostingView = NSHostingView(rootView: rowView)
        hostingView.frame.size = hostingView.fittingSize

        let item = NSMenuItem()
        item.view = hostingView
        item.representedObject = config.id
        item.target = self
        item.action = #selector(providerRowClicked(_:))

        // Attach native macOS-style secondary detail submenu
        let detailSubmenu = NSMenu()
        detailSubmenu.autoenablesItems = false

        let detailCard = ProviderDetailCardView(config: config, usage: usage, width: 280)
        let detailHostingView = NSHostingView(rootView: detailCard)
        detailHostingView.frame.size = detailHostingView.fittingSize

        let detailItem = NSMenuItem()
        detailItem.view = detailHostingView
        detailItem.isEnabled = false
        detailSubmenu.addItem(detailItem)

        item.submenu = detailSubmenu
        return item
    }

    private func makeCustomMenuItem<V: View>(view: V, width: CGFloat) -> NSMenuItem {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame.size = hostingView.fittingSize

        let item = NSMenuItem()
        item.view = hostingView
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func refreshAllClicked() {
        Task {
            await store.refreshAll()
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

    @objc private func loadSampleDataClicked() {
        store.seedSampleData()
        rebuildMenu()
    }

    @objc private func providerRowClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Task {
            await store.refreshProvider(id: id)
            rebuildMenu()
        }
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
