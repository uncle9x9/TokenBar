import Foundation

public struct MigrationResult: Sendable, Equatable {
    public let source: String
    public let enabledProviderIDs: [String]
    public let providerOrder: [String]
    public let refreshInterval: TimeInterval?
    public let resetTimeAsAbsolute: Bool?
    public let summary: String

    public init(
        source: String,
        enabledProviderIDs: [String],
        providerOrder: [String] = [],
        refreshInterval: TimeInterval? = nil,
        resetTimeAsAbsolute: Bool? = nil,
        summary: String
    ) {
        self.source = source
        self.enabledProviderIDs = enabledProviderIDs
        self.providerOrder = providerOrder
        self.refreshInterval = refreshInterval
        self.resetTimeAsAbsolute = resetTimeAsAbsolute
        self.summary = summary
    }
}

public enum ConfigurationMigrator {
    public static let candidateSuites: [String] = [
        "com.lobo.CodexBarMenuBar",
        "com.loboai.CodexBarMenuBar",
        "com.steipete.codexbar"
    ]

    public static let plistPaths: [String] = [
        NSHomeDirectory() + "/Library/Preferences/com.lobo.CodexBarMenuBar.plist",
        NSHomeDirectory() + "/Library/Preferences/com.loboai.CodexBarMenuBar.plist",
        NSHomeDirectory() + "/Library/Preferences/com.steipete.codexbar.plist"
    ]

    public static let jsonConfigPaths: [String] = [
        NSHomeDirectory() + "/.config/codexbar/config.json",
        NSHomeDirectory() + "/.codexbar/config.json"
    ]

    /// Detects if an existing configuration exists and can be imported.
    public static func detectMigrationSource() -> (source: String, available: Bool) {
        // 1. Check UserDefaults suites
        for suite in candidateSuites {
            if let defaults = UserDefaults(suiteName: suite),
               let enabled = defaults.array(forKey: "enabledProviderIDs") as? [String],
               !enabled.isEmpty {
                return (suite, true)
            }
        }

        // 2. Check Plist files on disk
        for path in plistPaths {
            if FileManager.default.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path),
               let enabled = dict["enabledProviderIDs"] as? [String],
               !enabled.isEmpty {
                let filename = (path as NSString).lastPathComponent
                return (filename, true)
            }
        }

        // 3. Check JSON configs
        for path in jsonConfigPaths {
            if FileManager.default.fileExists(atPath: path) {
                return ((path as NSString).lastPathComponent, true)
            }
        }

        return ("None", false)
    }

    /// Performs the migration from detected sources into TokenBar.
    @discardableResult
    public static func performMigration() -> MigrationResult? {
        // Strategy A: Try UserDefaults suite domains
        for suite in candidateSuites {
            if let defaults = UserDefaults(suiteName: suite),
               let enabled = defaults.array(forKey: "enabledProviderIDs") as? [String],
               !enabled.isEmpty {
                let order = (defaults.array(forKey: "providerOrder") as? [String]) ?? []
                let interval = defaults.double(forKey: "refreshInterval")
                let resetAbs = defaults.object(forKey: "resetTimeAsAbsolute") as? Bool

                return MigrationResult(
                    source: suite,
                    enabledProviderIDs: enabled,
                    providerOrder: order,
                    refreshInterval: interval > 0 ? interval : nil,
                    resetTimeAsAbsolute: resetAbs,
                    summary: "Imported \(enabled.count) enabled providers from \(suite)."
                )
            }
        }

        // Strategy B: Try reading Plist directly from disk
        for path in plistPaths {
            if FileManager.default.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path),
               let enabled = dict["enabledProviderIDs"] as? [String],
               !enabled.isEmpty {
                let order = (dict["providerOrder"] as? [String]) ?? []
                let interval = dict["refreshInterval"] as? Double
                let resetAbs = dict["resetTimeAsAbsolute"] as? Bool
                let filename = (path as NSString).lastPathComponent

                return MigrationResult(
                    source: filename,
                    enabledProviderIDs: enabled,
                    providerOrder: order,
                    refreshInterval: interval,
                    resetTimeAsAbsolute: resetAbs,
                    summary: "Imported \(enabled.count) enabled providers from \(filename)."
                )
            }
        }

        // Strategy C: Try reading CodexBar JSON config
        for path in jsonConfigPaths {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let providers = json["providers"] as? [[String: Any]] {
                var enabled: [String] = []
                for p in providers {
                    if let id = p["id"] as? String, (p["enabled"] as? Bool) == true {
                        enabled.append(id)
                    }
                }
                if !enabled.isEmpty {
                    return MigrationResult(
                        source: (path as NSString).lastPathComponent,
                        enabledProviderIDs: enabled,
                        providerOrder: enabled,
                        refreshInterval: nil,
                        resetTimeAsAbsolute: nil,
                        summary: "Imported \(enabled.count) enabled providers from \((path as NSString).lastPathComponent)."
                    )
                }
            }
        }

        return nil
    }
}
