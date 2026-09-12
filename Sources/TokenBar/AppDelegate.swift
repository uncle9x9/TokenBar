import AppKit
import TokenBarCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu-bar accessory item (LSUIElement behavior, no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Initialize status item and menu
        StatusItemController.shared.setup()

        // Start usage monitoring and background refresh
        UsageStore.shared.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        UsageStore.shared.stop()
    }
}
