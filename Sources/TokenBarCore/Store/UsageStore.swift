import Foundation
import Observation

@MainActor
@Observable
public final class UsageStore {
    public static let shared = UsageStore()

    public var usages: [String: ProviderUsage] = [:]

    public var enabledProviderIDs: [String] = [] {
        didSet {
            UserDefaults.standard.set(enabledProviderIDs, forKey: "enabledProviderIDs")
        }
    }

    public var providerOrder: [String] = [] {
        didSet {
            UserDefaults.standard.set(providerOrder, forKey: "providerOrder")
        }
    }

    public var displaySettings: [String: ProviderDisplaySettings] = [:] {
        didSet {
            saveDisplaySettings()
        }
    }

    public var presentation: MenuBarPresentation = .automatic {
        didSet {
            UserDefaults.standard.set(presentation.rawValue, forKey: "menuBarPresentation")
        }
    }

    public var maxVisibleInMenuBar: Int = 3 {
        didSet {
            UserDefaults.standard.set(maxVisibleInMenuBar, forKey: "maxVisibleInMenuBar")
        }
    }

    public var autoConsolidateThreshold: Int = 4 {
        didSet {
            UserDefaults.standard.set(autoConsolidateThreshold, forKey: "autoConsolidateThreshold")
        }
    }

    public var refreshInterval: Double = 300.0 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            restartTimer()
        }
    }

    public var resetTimeAsAbsolute: Bool = false {
        didSet {
            UserDefaults.standard.set(resetTimeAsAbsolute, forKey: "resetTimeAsAbsolute")
        }
    }

    public var onRefreshingChanged: ((Bool) -> Void)?
    public var isRefreshing: Bool = false {
        didSet {
            onRefreshingChanged?(isRefreshing)
        }
    }
    public var orbitProviderID: String = "" {
        didSet { UserDefaults.standard.set(orbitProviderID, forKey: "orbitProviderID") }
    }

    public var orbitWindowID: String = "session" {
        didSet { UserDefaults.standard.set(orbitWindowID, forKey: "orbitWindowID") }
    }

    public var orbitIconEnabled: Bool = true {
        didSet { UserDefaults.standard.set(orbitIconEnabled, forKey: "orbitIconEnabled") }
    }

    /// An unavailable selection follows provider order, never usage retrieval success.
    public var orbitConfig: ProviderConfig? {
        enabledConfigs.first { $0.id == orbitProviderID } ?? enabledConfigs.first
    }

    public var lastRefreshTime: Date?
    public var lastError: String?
    public var lastMigrationResult: MigrationResult?

    private var timerTask: Task<Void, Never>?
    private let cliBridge = CodexBarCLIBridge.shared

    public var enabledIDSet: Set<String> { Set(enabledProviderIDs) }

    public var enabledConfigs: [ProviderConfig] {
        let enabled = enabledIDSet
        return providerOrder.compactMap { id in
            guard enabled.contains(id) else { return nil }
            return ProviderConfig.byID[id]
        }
    }

    public var orderedProviderConfigs: [ProviderConfig] {
        providerOrder.compactMap { id in
            ProviderConfig.byID[id]
        }
    }

    /// Resolves the effective menu bar presentation (Horizontal vs Vertical vs Hybrid).
    public var effectivePresentation: MenuBarPresentation {
        switch presentation {
        case .hybrid:
            return .hybrid
        case .horizontal:
            return .horizontal
        case .vertical:
            return .vertical
        case .automatic:
            return enabledConfigs.count >= autoConsolidateThreshold ? .vertical : .horizontal
        }
    }

    /// Manually triggers migration from previous CodexBarMenuBar configuration.
    @discardableResult
    public func migrateFromPreviousConfig() -> MigrationResult? {
        guard let result = ConfigurationMigrator.performMigration() else { return nil }
        self.lastMigrationResult = result
        self.enabledProviderIDs = result.enabledProviderIDs
        if !result.providerOrder.isEmpty {
            self.providerOrder = result.providerOrder
        }
        if let interval = result.refreshInterval, interval > 0 {
            self.refreshInterval = interval
        }
        if let absolute = result.resetTimeAsAbsolute {
            self.resetTimeAsAbsolute = absolute
        }
        return result
    }

    public init() {
        let hasMigrated = UserDefaults.standard.bool(forKey: "tokenbar_migrated_from_upstream")

        if !hasMigrated && UserDefaults.standard.array(forKey: "enabledProviderIDs") == nil {
            if let result = ConfigurationMigrator.performMigration() {
                self.lastMigrationResult = result
                UserDefaults.standard.set(true, forKey: "tokenbar_migrated_from_upstream")
            }
        }

        if let savedEnabled = UserDefaults.standard.array(forKey: "enabledProviderIDs") as? [String], !savedEnabled.isEmpty {
            self.enabledProviderIDs = savedEnabled
        } else {
            self.enabledProviderIDs = ProviderConfig.defaultEnabledIDs
        }

        let allIDs = ProviderConfig.allProviders.map(\.id)
        if let savedOrder = UserDefaults.standard.array(forKey: "providerOrder") as? [String], !savedOrder.isEmpty {
            let allSet = Set(allIDs)
            var order = savedOrder.filter { allSet.contains($0) }
            let missing = allIDs.filter { !order.contains($0) }
            order.append(contentsOf: missing)
            self.providerOrder = order
        } else {
            self.providerOrder = allIDs
        }

        let savedInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        if savedInterval > 0 {
            self.refreshInterval = savedInterval
        }

        self.resetTimeAsAbsolute = UserDefaults.standard.bool(forKey: "resetTimeAsAbsolute")

        self.orbitProviderID = UserDefaults.standard.string(forKey: "orbitProviderID") ?? ""
        let savedOrbitWindow = UserDefaults.standard.string(forKey: "orbitWindowID")
        self.orbitWindowID = savedOrbitWindow == "weekly" ? "weekly" : "session"
        self.orbitIconEnabled = UserDefaults.standard.object(forKey: "orbitIconEnabled") as? Bool ?? true

        if let savedPresentationStr = UserDefaults.standard.string(forKey: "menuBarPresentation"),
           let p = MenuBarPresentation(rawValue: savedPresentationStr) {
            self.presentation = p
        } else {
            self.presentation = .automatic
        }

        let savedThreshold = UserDefaults.standard.integer(forKey: "autoConsolidateThreshold")
        if savedThreshold > 0 {
            self.autoConsolidateThreshold = savedThreshold
        } else {
            self.autoConsolidateThreshold = 4
        }

        let savedMaxVisible = UserDefaults.standard.integer(forKey: "maxVisibleInMenuBar")
        if savedMaxVisible > 0 {
            self.maxVisibleInMenuBar = savedMaxVisible
        } else {
            self.maxVisibleInMenuBar = 3
        }

        loadDisplaySettings()

        for id in enabledProviderIDs {
            if let config = ProviderConfig.byID[id] {
                self.usages[id] = ProviderUsage(id: config.id, displayName: config.displayName)
            }
        }
    }

    public func displaySetting(for id: String) -> ProviderDisplaySettings {
        displaySettings[id] ?? ProviderDisplaySettings()
    }

    public func usage(for id: String) -> ProviderUsage {
        usages[id] ?? (ProviderConfig.byID[id].map { ProviderUsage(id: $0.id, displayName: $0.displayName) } ?? ProviderUsage(id: id, displayName: id))
    }

    private func saveDisplaySettings() {
        if let data = try? JSONEncoder().encode(displaySettings) {
            UserDefaults.standard.set(data, forKey: "providerDisplaySettings")
        }
    }

    private func loadDisplaySettings() {
        if let data = UserDefaults.standard.data(forKey: "providerDisplaySettings"),
           let decoded = try? JSONDecoder().decode([String: ProviderDisplaySettings].self, from: data) {
            displaySettings = decoded
        }
    }

    public func start() {
        Task { await refreshAll() }
        restartTimer()
    }

    public func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    public func restartTimer() {
        stop()
        guard refreshInterval > 0 else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 300))
                await self?.refreshAll()
            }
        }
    }

    public func refreshAll() async {
        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshTime = Date()
        }

        let configs = enabledConfigs
        var results: [(String, Result<[CodexBarResponse], Error>)] = []

        await withTaskGroup(of: (String, Result<[CodexBarResponse], Error>).self) { group in
            for config in configs {
                group.addTask {
                    do {
                        let responses = try await self.cliBridge.fetchUsage(provider: config.cliName)
                        return (config.id, .success(responses))
                    } catch {
                        return (config.id, .failure(error))
                    }
                }
            }
            for await item in group {
                results.append(item)
            }
        }

        for (id, result) in results {
            guard let config = ProviderConfig.byID[id] else { continue }
            switch result {
            case .success(let responses):
                if let first = responses.first {
                    usages[id] = CodexBarCLIBridge.mapResponseToUsage(first, config: config)
                }
            case .failure(let error):
                var current = usages[id] ?? ProviderUsage(id: config.id, displayName: config.displayName)
                current.error = error.localizedDescription
                usages[id] = current
            }
        }
    }

    public func refreshProvider(id: String) async {
        guard let config = ProviderConfig.byID[id] else { return }
        do {
            let responses = try await cliBridge.fetchUsage(provider: config.cliName)
            if let first = responses.first {
                usages[id] = CodexBarCLIBridge.mapResponseToUsage(first, config: config)
            }
        } catch {
            var current = usages[id] ?? ProviderUsage(id: config.id, displayName: config.displayName)
            current.error = error.localizedDescription
            usages[id] = current
        }
    }

    public func seedSampleData() {
        usages["claude"] = ProviderUsage(
            id: "claude",
            displayName: "Claude",
            sessionPercent: 20.0,
            sessionWindowMinutes: 300,
            sessionResetsAt: Date().addingTimeInterval(3600 * 2.5),
            weeklyPercent: 18.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: Date().addingTimeInterval(86400 * 5),
            accountOrganization: "Sample Organization",
            source: "web",
            lastUpdated: Date()
        )

        usages["codex"] = ProviderUsage(
            id: "codex",
            displayName: "Codex",
            sessionPercent: 0.0,
            sessionWindowMinutes: 300,
            sessionResetsAt: Date().addingTimeInterval(3600 * 4),
            weeklyPercent: 0.0,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: Date().addingTimeInterval(86400 * 6),
            accountOrganization: "Plus Plan",
            source: "oauth",
            lastUpdated: Date()
        )

        usages["antigravity"] = ProviderUsage(
            id: "antigravity",
            displayName: "Antigrav",
            sessionPercent: 20.5,
            sessionWindowMinutes: 300,
            sessionResetsAt: Date().addingTimeInterval(3600 * 2.4),
            weeklyPercent: 4.7,
            weeklyWindowMinutes: 10080,
            weeklyResetsAt: Date().addingTimeInterval(86400 * 2.8),
            accountOrganization: "Google AI Pro",
            source: "app",
            lastUpdated: Date()
        )

        usages["deepseek"] = ProviderUsage(
            id: "deepseek",
            displayName: "DeepSeek",
            balance: "¥32.50",
            source: "api",
            lastUpdated: Date()
        )

        lastRefreshTime = Date()
    }
}
