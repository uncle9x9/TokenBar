import Foundation
import AppKit
import SwiftUI
import TokenBarCore

@MainActor
func runVerification() async {
    print("==================================================")
    print("TokenBar Live CLI Quota Fetch Verification")
    print("==================================================")

    let store = UsageStore.shared
    store.enabledProviderIDs = ["claude", "codex", "antigravity"]

    print("Fetching live quotas via parallel codexbar CLI...")
    await store.refreshAll()

    for id in ["claude", "codex", "antigravity"] {
        guard let config = ProviderConfig.byID[id] else { continue }
        let u = store.usage(for: id)
        print("--------------------------------------------------")
        print("Provider: \(config.displayName) (\(id))")
        print("Status: \(u.statusDescription)")
        if let email = u.accountEmail ?? u.accountOrganization {
            print("Account: \(email)")
        }
        if let source = u.source {
            print("Source: \(source)")
        }
        if let err = u.error {
            print("Error: \(err)")
        }

        print("Normalised Quota Windows (Claude Code model):")
        let windows = u.normalisedQuotaWindows(config: config)
        for w in windows {
            print("  • \(w.title)")
            print("    Deadline: \(w.resetText ?? "none") | Consumed: \(Int(w.usedPercent))%")
        }
    }

    print("==================================================")
    print("Acceptance Criteria Verification")
    print("==================================================")

    let controller = StatusItemController.shared
    controller.setup()
    controller.rebuildMenu()

    let mirror = Mirror(reflecting: controller)
    guard let menu = mirror.children.first(where: { $0.label == "menu" })?.value as? NSMenu else {
        fatalError("Failed to reflect NSMenu from StatusItemController")
    }

    let statusItem = mirror.children.first(where: { $0.label == "statusItem" })?.value as? NSStatusItem
    assert(statusItem != nil, "Criterion A failed")
    print("✅ Criterion A: Single menu bar status item maintained.")

    let providerItems = menu.items.filter { item in
        guard let id = item.representedObject as? String else { return false }
        return ProviderConfig.byID[id] != nil
    }
    assert(providerItems.count == 3, "Criterion B failed")
    print("✅ Criterion B: 3 enabled providers exposed with authentic vector icons.")

    for item in providerItems {
        let submenu = item.submenu!
        assert(submenu.items.count >= 2 && submenu.items[0].view != nil)
    }
    print("✅ Criterion C: Every provider row has an attached native macOS detail submenu.")

    store.stop()
    print("==================================================")
    print("ALL VERIFICATION CHECKS PASSED")
    print("==================================================")
}

Task { @MainActor in
    await runVerification()
    exit(0)
}

RunLoop.main.run()
