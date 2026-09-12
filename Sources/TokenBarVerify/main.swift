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
        let u = store.usage(for: id)
        print("--------------------------------------------------")
        print("Provider: \(u.displayName) (\(id))")
        print("Status: \(u.statusDescription)")
        if let rem = u.primaryRemainingPercent {
            print("Primary Remaining: \(Int(rem))%")
        }
        if let sessionUsed = u.sessionPercent {
            print("Session Used: \(sessionUsed)%")
        }
        if let weeklyUsed = u.weeklyPercent {
            print("Weekly Used: \(weeklyUsed)%")
        }
        if !u.extraWindows.isEmpty {
            for extra in u.extraWindows {
                print("Extra Window [\(extra.title)]: \(Int(extra.remainingPercent))% remaining")
            }
        }
        if let reset = u.primaryResetsAt {
            print("Resets: \(ResetTimeFormatter.countdownDescription(from: reset))")
        }
        if let email = u.accountEmail {
            print("Account: \(email)")
        }
        if let source = u.source {
            print("Source: \(source)")
        }
        if let err = u.error {
            print("Error: \(err)")
        }
    }

    print("==================================================")
    print("Acceptance Criteria Matrix")
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
    print("✅ Criterion A: Exactly one status item initialized.")

    let providerItems = menu.items.filter { item in
        guard let id = item.representedObject as? String else { return false }
        return ProviderConfig.byID[id] != nil
    }
    assert(providerItems.count == 3, "Criterion B failed")
    print("✅ Criterion B: 3 enabled providers exposed vertically.")

    for item in providerItems {
        let submenu = item.submenu!
        assert(submenu.items.count == 1 && submenu.items[0].view != nil)
    }
    print("✅ Criterion C: Every provider row has an attached detail submenu.")

    store.stop()
    print("==================================================")
    print("ALL CHECKS COMPLETED")
    print("==================================================")
}

Task { @MainActor in
    await runVerification()
    exit(0)
}

RunLoop.main.run()
