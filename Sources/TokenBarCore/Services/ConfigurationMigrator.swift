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
        "com.loboai.CodexBarMenuBar"
    ]

    public static let plistPaths: [String] = [
        NSHomeDirectory() + "/Library/Preferences/com.lobo.CodexBarMenuBar.plist",
        NSHomeDirectory() + "/Library/Preferences/com.loboai.CodexBarMenuBar.plist"
    ]

    /// Detects if an existing CodexBarMenuBar configuration exists.
    public static func detectMigrationSource() -> (source: String, available: Bool) {
        for suite in candidateSuites {
            if let defaults = UserDefaults(suiteName: suite),
               let enabled = defaults.array(forKey: "enabledProviderIDs") as? [String],
               !enabled.isEmpty {
                return (suite, true)
            }
        }

        for path in plistPaths {
            if FileManager.default.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path),
               let enabled = dict["enabledProviderIDs"] as? [String],
               !enabled.isEmpty {
                return ((path as NSString).lastPathComponent, true)
            }
        }

        return ("None", false)
    }

    /// Migrates all settings from CodexBarMenuBar into UserDefaults.standard.
    @discardableResult
    public static func performMigration() -> MigrationResult? {
        let standard = UserDefaults.standard

        // Strategy 1: UserDefaults suite
        for suite in candidateSuites {
            if let defaults = UserDefaults(suiteName: suite),
               let enabled = defaults.array(forKey: "enabledProviderIDs") as? [String],
               !enabled.isEmpty {
                copySettings(from: defaults, to: standard)
                return MigrationResult(
                    source: suite,
                    enabledProviderIDs: enabled,
                    providerOrder: (defaults.array(forKey: "providerOrder") as? [String]) ?? [],
                    refreshInterval: defaults.double(forKey: "refreshInterval"),
                    resetTimeAsAbsolute: defaults.bool(forKey: "resetTimeAsAbsolute"),
                    summary: "Imported settings from \(suite) with \(enabled.count) providers."
                )
            }
        }

        // Strategy 2: Direct Plist file read
        for path in plistPaths {
            if FileManager.default.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
               let enabled = dict["enabledProviderIDs"] as? [String],
               !enabled.isEmpty {
                copySettings(from: dict, to: standard)
                return MigrationResult(
                    source: (path as NSString).lastPathComponent,
                    enabledProviderIDs: enabled,
                    providerOrder: (dict["providerOrder"] as? [String]) ?? [],
                    refreshInterval: dict["refreshInterval"] as? Double,
                    resetTimeAsAbsolute: dict["resetTimeAsAbsolute"] as? Bool,
                    summary: "Imported settings from \((path as NSString).lastPathComponent) with \(enabled.count) providers."
                )
            }
        }

        return nil
    }

    private static func copySettings(from source: UserDefaults, to target: UserDefaults) {
        let keys = [
            "enabledProviderIDs", "providerOrder", "refreshInterval",
            "resetTimeAsAbsolute", "showUsageAsUsed", "colorPercentText",
            "colorCountdownText", "showThresholdTicks", "showWorkdayMarkers",
            "batterySaverEnabled", "launchAtLogin", "quotaNotifEnabled",
            "quotaNotifWarningThreshold", "quotaNotifCriticalThreshold",
            "providerDisplaySettings"
        ]
        for key in keys {
            if let val = source.object(forKey: key) {
                target.set(val, forKey: key)
            }
        }
    }

    private static func copySettings(from dict: [String: Any], to target: UserDefaults) {
        let keys = [
            "enabledProviderIDs", "providerOrder", "refreshInterval",
            "resetTimeAsAbsolute", "showUsageAsUsed", "colorPercentText",
            "colorCountdownText", "showThresholdTicks", "showWorkdayMarkers",
            "batterySaverEnabled", "launchAtLogin", "quotaNotifEnabled",
            "quotaNotifWarningThreshold", "quotaNotifCriticalThreshold",
            "providerDisplaySettings"
        ]
        for key in keys {
            if let val = dict[key] {
                target.set(val, forKey: key)
            }
        }
    }
}
