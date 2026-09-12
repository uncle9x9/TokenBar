import Foundation
import Observation

@MainActor
@Observable
public final class UsageStore {
    public static let shared = UsageStore()

    public var usages: [String: ProviderUsage] = [:]

    public var enabledProviderIDs: [String] = [] {
        didSet {
            UserDefaults.standard.set(enabledProviderIDs, forKey: "tokenbar_enabled_provider_ids")
        }
    }

    public var providerOrder: [String] = [] {
        didSet {
            UserDefaults.standard.set(providerOrder, forKey: "tokenbar_provider_order")
        }
    }

    public var refreshInterval: TimeInterval = 120.0 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "tokenbar_refresh_interval")
            restartTimer()
        }
    }

    public var resetTimeAsAbsolute: Bool = false {
        didSet {
            UserDefaults.standard.set(resetTimeAsAbsolute, forKey: "tokenbar_reset_as_absolute")
        }
    }

    public var isRefreshing: Bool = false
    public var lastRefreshTime: Date?
    public var lastError: String?
    public var lastMigrationResult: MigrationResult?

    private var timerTask: Task<Void, Never>?
    private let cliBridge = CodexBarCLIBridge.shared

    public init() {
        let hasMigrated = UserDefaults.standard.bool(forKey: "tokenbar_migration_completed")

        if let saved = UserDefaults.standard.stringArray(forKey: "tokenbar_enabled_provider_ids"), !saved.isEmpty {
            self.enabledProviderIDs = saved
        } else {
            self.enabledProviderIDs = ProviderConfig.defaultEnabledIDs
        }

        if let savedOrder = UserDefaults.standard.stringArray(forKey: "tokenbar_provider_order"), !savedOrder.isEmpty {
            self.providerOrder = savedOrder
        } else {
            self.providerOrder = ProviderConfig.allProviders.map(\.id)
        }

        let savedInterval = UserDefaults.standard.double(forKey: "tokenbar_refresh_interval")
        if savedInterval > 0 {
            self.refreshInterval = savedInterval
        }

        self.resetTimeAsAbsolute = UserDefaults.standard.bool(forKey: "tokenbar_reset_as_absolute")

        // First launch auto-migration from previous CodexBarMenuBar if available
        if !hasMigrated {
            checkAndRunFirstLaunchMigration()
        }

        // Initialize empty records for enabled providers
        for id in enabledProviderIDs {
            if let config = ProviderConfig.byID[id] {
                self.usages[id] = ProviderUsage.empty(config: config)
            }
        }
    }

    /// Automatically migrates settings from previous CodexBarMenuBar installation if present.
    public func checkAndRunFirstLaunchMigration() {
        if let result = ConfigurationMigrator.performMigration() {
            applyMigrationResult(result)
            UserDefaults.standard.set(true, forKey: "tokenbar_migration_completed")
            UserDefaults.standard.set(result.source, forKey: "tokenbar_migration_source")
        }
    }

    /// Manually triggers migration from previous CodexBarMenuBar configuration.
    @discardableResult
    public func migrateFromPreviousConfig() -> MigrationResult? {
        guard let result = ConfigurationMigrator.performMigration() else { return nil }
        applyMigrationResult(result)
        UserDefaults.standard.set(true, forKey: "tokenbar_migration_completed")
        UserDefaults.standard.set(result.source, forKey: "tokenbar_migration_source")
        return result
    }

    private func applyMigrationResult(_ result: MigrationResult) {
        self.lastMigrationResult = result

        // Filter valid known provider IDs
        let validIDs = result.enabledProviderIDs.filter { ProviderConfig.byID[$0] != nil }
        if !validIDs.isEmpty {
            self.enabledProviderIDs = validIDs
        }

        if !result.providerOrder.isEmpty {
            self.providerOrder = result.providerOrder.filter { ProviderConfig.byID[$0] != nil }
        }

        if let interval = result.refreshInterval, interval > 0 {
            self.refreshInterval = interval
        }

        if let absolute = result.resetTimeAsAbsolute {
            self.resetTimeAsAbsolute = absolute
        }

        for id in enabledProviderIDs {
            if self.usages[id] == nil, let config = ProviderConfig.byID[id] {
                self.usages[id] = ProviderUsage.empty(config: config)
            }
        }
    }

    /// Returns enabled configs ordered according to providerOrder, with any remaining at the end.
    public var enabledConfigs: [ProviderConfig] {
        let enabled = Set(enabledProviderIDs)
        var configs: [ProviderConfig] = []
        var added = Set<String>()

        for id in providerOrder {
            if enabled.contains(id), let config = ProviderConfig.byID[id], !added.contains(id) {
                configs.append(config)
                added.insert(id)
            }
        }

        for id in enabledProviderIDs {
            if !added.contains(id), let config = ProviderConfig.byID[id] {
                configs.append(config)
                added.insert(id)
            }
        }

        return configs
    }

    public func usage(for id: String) -> ProviderUsage {
        usages[id] ?? ProviderUsage(id: id, displayName: ProviderConfig.byID[id]?.displayName ?? id)
    }

    public func start() {
        startTimer()
        Task {
            await refreshAll()
        }
    }

    public func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    public func restartTimer() {
        stop()
        startTimer()
    }

    private func startTimer() {
        guard refreshInterval > 0 else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.refreshInterval ?? 120.0) * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.refreshAll()
            }
        }
    }

    public func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer {
            isRefreshing = false
            lastRefreshTime = Date()
            StatusItemController.shared.rebuildMenu()
        }

        let configs = enabledConfigs
        guard !configs.isEmpty else { return }

        await withTaskGroup(of: (String, Result<CodexBarResponse, Error>).self) { group in
            for config in configs {
                group.addTask {
                    do {
                        let results = try await self.cliBridge.fetchUsage(provider: config.cliName, timeoutSeconds: 15.0)
                        if let first = results.first {
                            return (config.id, .success(first))
                        }
                        throw CLIBridgeError.executionFailed("Empty response from codexbar")
                    } catch {
                        return (config.id, .failure(error))
                    }
                }
            }

            for await (id, result) in group {
                guard let config = ProviderConfig.byID[id] else { continue }
                switch result {
                case .success(let response):
                    self.usages[id] = CodexBarCLIBridge.mapResponseToUsage(response, config: config)
                case .failure(let err):
                    var existing = self.usages[id] ?? ProviderUsage.empty(config: config)
                    existing.error = err.localizedDescription
                    self.usages[id] = existing
                }
            }
        }
    }

    public func refreshProvider(id: String) async {
        guard let config = ProviderConfig.byID[id] else { return }
        defer {
            StatusItemController.shared.rebuildMenu()
        }
        do {
            let results = try await cliBridge.fetchUsage(provider: config.cliName, timeoutSeconds: 10.0)
            if let first = results.first {
                self.usages[id] = CodexBarCLIBridge.mapResponseToUsage(first, config: config)
            }
        } catch {
            var existing = self.usages[id] ?? ProviderUsage.empty(config: config)
            existing.error = error.localizedDescription
            self.usages[id] = existing
        }
    }

    /// Seeds realistic mock data for preview/demonstration if no live CLI is connected.
    public func seedSampleData() {
        let now = Date()
        self.usages["claude"] = ProviderUsage(
            id: "claude",
            displayName: "Claude",
            sessionPercent: 49.0,
            sessionWindowMinutes: 300,
            sessionResetsAt: now.addingTimeInterval(3600 * 2.5),
            weeklyPercent: 71.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: now.addingTimeInterval(3600 * 54),
            extraWindows: [
                ExtraWindowUsage(id: "opus", title: "Opus Allowance", usedPercent: 18.0, resetsAt: now.addingTimeInterval(3600 * 2.5))
            ],
            accountEmail: "developer@anthropic.com",
            source: "Web",
            lastUpdated: now
        )

        self.usages["codex"] = ProviderUsage(
            id: "codex",
            displayName: "OpenAI / Codex",
            sessionPercent: 0.0,
            sessionWindowMinutes: 180,
            sessionResetsAt: now.addingTimeInterval(3600 * 1.8),
            weeklyPercent: 71.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: now.addingTimeInterval(3600 * 61),
            extraWindows: [
                ExtraWindowUsage(id: "gpt4_review", title: "Code Review", usedPercent: 87.0, resetsAt: now.addingTimeInterval(3600 * 61))
            ],
            accountOrganization: "OpenAI Team",
            source: "OAuth",
            lastUpdated: now
        )

        self.usages["gemini"] = ProviderUsage(
            id: "gemini",
            displayName: "Gemini",
            sessionPercent: 100.0,
            sessionWindowMinutes: 60,
            sessionResetsAt: now.addingTimeInterval(3600 * 0.4),
            weeklyPercent: 22.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: now.addingTimeInterval(3600 * 80),
            source: "Google AI",
            lastUpdated: now
        )

        self.usages["antigravity"] = ProviderUsage(
            id: "antigravity",
            displayName: "Antigravity",
            sessionPercent: 100.0,
            sessionWindowMinutes: 1440,
            sessionResetsAt: now.addingTimeInterval(3600 * 14),
            weeklyPercent: 35.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: now.addingTimeInterval(3600 * 92),
            source: "AGY SDK",
            lastUpdated: now
        )

        self.usages["cursor"] = ProviderUsage(
            id: "cursor",
            displayName: "Cursor",
            sessionPercent: 36.0,
            sessionWindowMinutes: 1440,
            sessionResetsAt: now.addingTimeInterval(3600 * 8),
            weeklyPercent: 55.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: now.addingTimeInterval(3600 * 110),
            source: "Cursor Pro",
            lastUpdated: now
        )
    }
}
