import Foundation

public enum DisplayType: String, Codable, Sendable {
    case usageBar
    case balance
}

public typealias DisplayMetricType = DisplayType

public enum MenuBarPresentation: String, Codable, CaseIterable, Sendable {
    case automatic = "automatic"
    case horizontal = "horizontal"
    case vertical = "vertical"

    public var title: String {
        switch self {
        case .automatic: return "Automatic (1–3 Horizontal, 4+ Consolidated)"
        case .horizontal: return "Horizontal / Original (Classic CodexBarMenuBar)"
        case .vertical: return "Vertical / Single Icon"
        }
    }
}

public struct WindowDisplaySettings: Codable, Equatable, Sendable {
    public var showBar: Bool
    public var showPercent: Bool
    public var showCountdownBar: Bool
    public var showCountdownText: Bool

    public init(showBar: Bool = true, showPercent: Bool = true, showCountdownBar: Bool = false, showCountdownText: Bool = false) {
        self.showBar = showBar
        self.showPercent = showPercent
        self.showCountdownBar = showCountdownBar
        self.showCountdownText = showCountdownText
    }

    public static func defaults(for key: String) -> WindowDisplaySettings {
        switch key {
        case "session":
            return WindowDisplaySettings(showBar: true, showPercent: true, showCountdownBar: false, showCountdownText: false)
        case "weekly":
            return WindowDisplaySettings(showBar: false, showPercent: true, showCountdownBar: false, showCountdownText: false)
        default:
            return WindowDisplaySettings(showBar: false, showPercent: false, showCountdownBar: false, showCountdownText: false)
        }
    }
}

public struct ProviderDisplaySettings: Codable, Sendable, Equatable {
    public var windowSettings: [String: WindowDisplaySettings] = [:]
    public var showBalance: Bool = true

    public init(windowSettings: [String: WindowDisplaySettings] = [:], showBalance: Bool = true) {
        self.windowSettings = windowSettings
        self.showBalance = showBalance
    }

    public func settings(for key: String) -> WindowDisplaySettings {
        windowSettings[key] ?? WindowDisplaySettings.defaults(for: key)
    }

    public mutating func setSettings(for key: String, _ value: WindowDisplaySettings) {
        windowSettings[key] = value
    }
}

public struct ProviderConfig: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let cliName: String
    public let displayType: DisplayType
    public let sessionField: RateWindowField
    public let weeklyField: RateWindowField?
    public let balanceField: RateWindowField?

    public enum RateWindowField: String, Codable, Sendable {
        case primary, secondary, tertiary
    }

    public init(
        id: String,
        displayName: String,
        cliName: String,
        displayType: DisplayType = .usageBar,
        sessionField: RateWindowField = .primary,
        weeklyField: RateWindowField? = .secondary,
        balanceField: RateWindowField? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.cliName = cliName
        self.displayType = displayType
        self.sessionField = sessionField
        self.weeklyField = weeklyField
        self.balanceField = balanceField
    }
}

public extension ProviderConfig {
    static let allProviders: [ProviderConfig] = [
        // Subscription with usage windows
        ProviderConfig(id: "claude", displayName: "Claude", cliName: "claude", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "codex", displayName: "Codex", cliName: "codex", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "zai", displayName: "ZAI", cliName: "zai", displayType: .usageBar,
                       sessionField: .tertiary, weeklyField: .primary, balanceField: nil),
        ProviderConfig(id: "cursor", displayName: "Cursor", cliName: "cursor", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "gemini", displayName: "Gemini", cliName: "gemini", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "copilot", displayName: "Copilot", cliName: "copilot", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "windsurf", displayName: "Windsurf", cliName: "windsurf", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "opencode", displayName: "OpenCode", cliName: "opencode", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "opencodego", displayName: "OC Go", cliName: "opencodego", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "alibaba", displayName: "Alibaba", cliName: "alibaba-coding-plan", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "antigravity", displayName: "Antigrav", cliName: "antigravity", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "kiro", displayName: "Kiro", cliName: "kiro", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "minimax", displayName: "MiniMax", cliName: "minimax", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "kimi", displayName: "Kimi", cliName: "kimi", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "factory", displayName: "Droid", cliName: "factory", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "augment", displayName: "Augment", cliName: "augment", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "jetbrains", displayName: "JB AI", cliName: "jetbrains", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "vertexai", displayName: "Vertex", cliName: "vertexai", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "mistral", displayName: "Mistral", cliName: "mistral", displayType: .usageBar,
                       sessionField: .primary, weeklyField: nil, balanceField: nil),
        ProviderConfig(id: "synthetic", displayName: "Synthetic", cliName: "synthetic", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "codebuff", displayName: "Codebuff", cliName: "codebuff", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "abacusai", displayName: "Abacus", cliName: "abacusai", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "perplexity", displayName: "Perplx", cliName: "perplexity", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "amp", displayName: "Amp", cliName: "amp", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),

        // Balance / credit based
        ProviderConfig(id: "deepseek", displayName: "DeepSeek", cliName: "deepseek", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "openrouter", displayName: "ORouter", cliName: "openrouter", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "warp", displayName: "Warp", cliName: "warp", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "kilo", displayName: "Kilo", cliName: "kilo", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "kimik2", displayName: "KimiK2", cliName: "kimik2", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),

        // Local
        ProviderConfig(id: "ollama", displayName: "Ollama", cliName: "ollama", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),

        // CodexBar CLI additions
        ProviderConfig(id: "openai", displayName: "OpenAI", cliName: "openai", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "manus", displayName: "Manus", cliName: "manus", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "moonshot", displayName: "Moonshot", cliName: "moonshot", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "mimo", displayName: "MiMo", cliName: "mimo", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "doubao", displayName: "Doubao", cliName: "doubao", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "crof", displayName: "Crof", cliName: "crof", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "venice", displayName: "Venice", cliName: "venice", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "commandcode", displayName: "CmdCode", cliName: "commandcode", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "stepfun", displayName: "StepFun", cliName: "stepfun", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "bedrock", displayName: "Bedrock", cliName: "bedrock", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "elevenlabs", displayName: "11Labs", cliName: "elevenlabs", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "grok", displayName: "Grok", cliName: "grok", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "xai", displayName: "xAI", cliName: "xai", displayType: .balance,
                       sessionField: .primary, weeklyField: nil, balanceField: .primary),
        ProviderConfig(id: "groqcloud", displayName: "Groq", cliName: "groqcloud", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "llmproxy", displayName: "LLMProxy", cliName: "llmproxy", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "deepgram", displayName: "Deepgram", cliName: "deepgram", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "azureopenai", displayName: "Azure", cliName: "azure-openai", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "t3chat", displayName: "T3 Chat", cliName: "t3chat", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
        ProviderConfig(id: "alibabatokenplan", displayName: "Bailian", cliName: "alibaba-token-plan", displayType: .usageBar,
                       sessionField: .primary, weeklyField: .secondary, balanceField: nil),
    ]

    static let defaultEnabledIDs: [String] = ["claude", "codex", "antigravity"]

    static let byID: [String: ProviderConfig] = {
        Dictionary(uniqueKeysWithValues: allProviders.map { ($0.id, $0) })
    }()
}
