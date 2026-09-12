import Foundation

public enum DisplayMetricType: String, Codable, Sendable {
    case usageBar
    case balance
}

public struct ProviderConfig: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let cliName: String
    public let displayType: DisplayMetricType
    public let systemImage: String
    public let tintHex: UInt32
    public let defaultEnabled: Bool

    public init(
        id: String,
        displayName: String,
        cliName: String,
        displayType: DisplayMetricType = .usageBar,
        systemImage: String = "cpu",
        tintHex: UInt32 = 0x007AFF,
        defaultEnabled: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.cliName = cliName
        self.displayType = displayType
        self.systemImage = systemImage
        self.tintHex = tintHex
        self.defaultEnabled = defaultEnabled
    }
}

public extension ProviderConfig {
    static let allProviders: [ProviderConfig] = [
        ProviderConfig(id: "claude", displayName: "Claude", cliName: "claude", displayType: .usageBar, systemImage: "sparkles", tintHex: 0xD97706, defaultEnabled: true),
        ProviderConfig(id: "codex", displayName: "OpenAI / Codex", cliName: "codex", displayType: .usageBar, systemImage: "brain.head.profile", tintHex: 0x10A37F, defaultEnabled: true),
        ProviderConfig(id: "gemini", displayName: "Gemini", cliName: "gemini", displayType: .usageBar, systemImage: "atom", tintHex: 0x2563EB, defaultEnabled: true),
        ProviderConfig(id: "antigravity", displayName: "Antigravity", cliName: "antigravity", displayType: .usageBar, systemImage: "bolt.fill", tintHex: 0x8B5CF6, defaultEnabled: true),
        ProviderConfig(id: "cursor", displayName: "Cursor", cliName: "cursor", displayType: .usageBar, systemImage: "cursorarrow.rays", tintHex: 0x06B6D4, defaultEnabled: true),
        ProviderConfig(id: "copilot", displayName: "Copilot", cliName: "copilot", displayType: .usageBar, systemImage: "airplane", tintHex: 0x3B82F6, defaultEnabled: true),
        ProviderConfig(id: "windsurf", displayName: "Windsurf", cliName: "windsurf", displayType: .usageBar, systemImage: "wind", tintHex: 0x14B8A6, defaultEnabled: false),
        ProviderConfig(id: "opencode", displayName: "OpenCode", cliName: "opencode", displayType: .usageBar, systemImage: "chevron.left.forwardslash.chevron.right", tintHex: 0x6366F1, defaultEnabled: false),
        ProviderConfig(id: "deepseek", displayName: "DeepSeek", cliName: "deepseek", displayType: .balance, systemImage: "fish.fill", tintHex: 0x0EA5E9, defaultEnabled: false),
        ProviderConfig(id: "openrouter", displayName: "OpenRouter", cliName: "openrouter", displayType: .balance, systemImage: "arrow.triangle.branch", tintHex: 0xEC4899, defaultEnabled: false),
        ProviderConfig(id: "kimi", displayName: "Kimi", cliName: "kimi", displayType: .usageBar, systemImage: "moon.stars.fill", tintHex: 0xF59E0B, defaultEnabled: false),
        ProviderConfig(id: "minimax", displayName: "MiniMax", cliName: "minimax", displayType: .usageBar, systemImage: "dial.low.fill", tintHex: 0xEF4444, defaultEnabled: false),
        ProviderConfig(id: "kiro", displayName: "Kiro", cliName: "kiro", displayType: .usageBar, systemImage: "hammer.fill", tintHex: 0x84CC16, defaultEnabled: false),
        ProviderConfig(id: "zai", displayName: "ZAI", cliName: "zai", displayType: .usageBar, systemImage: "waveform.path.ecg", tintHex: 0xA855F7, defaultEnabled: false),
        ProviderConfig(id: "alibaba", displayName: "Alibaba", cliName: "alibaba-coding-plan", displayType: .usageBar, systemImage: "cloud.sun.fill", tintHex: 0xF97316, defaultEnabled: false),
        ProviderConfig(id: "augment", displayName: "Augment", cliName: "augment", displayType: .usageBar, systemImage: "plus.circle.fill", tintHex: 0x10B981, defaultEnabled: false),
        ProviderConfig(id: "factory", displayName: "Droid", cliName: "factory", displayType: .usageBar, systemImage: "gearshape.2.fill", tintHex: 0x64748B, defaultEnabled: false),
        ProviderConfig(id: "mistral", displayName: "Mistral", cliName: "mistral", displayType: .usageBar, systemImage: "flame.fill", tintHex: 0xF43F5E, defaultEnabled: false),
        ProviderConfig(id: "perplexity", displayName: "Perplexity", cliName: "perplexity", displayType: .usageBar, systemImage: "magnifyingglass", tintHex: 0x22D3EE, defaultEnabled: false)
    ]

    static let defaultEnabledIDs: [String] = [
        "claude", "codex", "gemini", "antigravity", "cursor"
    ]

    static let byID: [String: ProviderConfig] = {
        Dictionary(uniqueKeysWithValues: allProviders.map { ($0.id, $0) })
    }()
}
