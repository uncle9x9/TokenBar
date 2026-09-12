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
    public var refreshInterval: TimeInterval = 120.0 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "tokenbar_refresh_interval")
            restartTimer()
        }
    }

    public var isRefreshing: Bool = false
    public var lastRefreshTime: Date?
    public var lastError: String?

    private var timerTask: Task<Void, Never>?
    private let cliBridge = CodexBarCLIBridge.shared

    public init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "tokenbar_enabled_provider_ids"), !saved.isEmpty {
            self.enabledProviderIDs = saved
        } else {
            self.enabledProviderIDs = ProviderConfig.defaultEnabledIDs
        }

        let savedInterval = UserDefaults.standard.double(forKey: "tokenbar_refresh_interval")
        if savedInterval > 0 {
            self.refreshInterval = savedInterval
        }

        // Initialize empty records for enabled providers
        for id in enabledProviderIDs {
            if let config = ProviderConfig.byID[id] {
                self.usages[id] = ProviderUsage.empty(config: config)
            }
        }
    }

    public var enabledConfigs: [ProviderConfig] {
        let set = Set(enabledProviderIDs)
        return ProviderConfig.allProviders.filter { set.contains($0.id) }
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
        }

        let configs = enabledConfigs
        guard !configs.isEmpty else { return }

        // First attempt: try single bulk CLI fetch
        do {
            let responses = try await cliBridge.fetchUsage(provider: nil, timeoutSeconds: 20.0)
            let responseMap = Dictionary(grouping: responses, by: \.provider)

            for config in configs {
                if let matching = responseMap[config.cliName]?.first ?? responseMap[config.id]?.first {
                    self.usages[config.id] = CodexBarCLIBridge.mapResponseToUsage(matching, config: config)
                }
            }
            return
        } catch {
            // Bulk fetch failed or unsupported; fall back to parallel per-provider fetch
            await withTaskGroup(of: (String, Result<CodexBarResponse, Error>).self) { group in
                for config in configs {
                    group.addTask {
                        do {
                            let results = try await self.cliBridge.fetchUsage(provider: config.cliName, timeoutSeconds: 10.0)
                            if let first = results.first {
                                return (config.id, .success(first))
                            }
                            throw CLIBridgeError.executionFailed("Empty response")
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
    }

    public func refreshProvider(id: String) async {
        guard let config = ProviderConfig.byID[id] else { return }
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
