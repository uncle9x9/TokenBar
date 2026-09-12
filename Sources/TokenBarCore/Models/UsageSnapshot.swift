import Foundation

public struct RateWindow: Codable, Sendable, Equatable {
    public let usedPercent: Double
    public let windowMinutes: Int?
    public let resetsAt: Date?
    public let resetDescription: String?
    public let nextRegenPercent: Double?

    public init(
        usedPercent: Double,
        windowMinutes: Int? = nil,
        resetsAt: Date? = nil,
        resetDescription: String? = nil,
        nextRegenPercent: Double? = nil
    ) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.resetDescription = resetDescription
        self.nextRegenPercent = nextRegenPercent
    }

    public var remainingPercent: Double {
        max(0, 100.0 - usedPercent)
    }

    enum CodingKeys: String, CodingKey {
        case usedPercent
        case windowMinutes
        case resetsAt
        case resetDescription
        case nextRegenPercent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.usedPercent = try container.decode(Double.self, forKey: .usedPercent)
        self.windowMinutes = try container.decodeIfPresent(Int.self, forKey: .windowMinutes)
        self.resetDescription = try container.decodeIfPresent(String.self, forKey: .resetDescription)
        self.nextRegenPercent = try container.decodeIfPresent(Double.self, forKey: .nextRegenPercent)

        if let date = try? container.decodeIfPresent(Date.self, forKey: .resetsAt) {
            self.resetsAt = date
        } else if let dateStr = try? container.decodeIfPresent(String.self, forKey: .resetsAt) {
            self.resetsAt = ISO8601DateFormatter().date(from: dateStr)
        } else {
            self.resetsAt = nil
        }
    }
}

public struct NamedRateWindow: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let window: RateWindow

    public init(id: String, title: String, window: RateWindow) {
        self.id = id
        self.title = title
        self.window = window
    }
}

public struct AccountIdentity: Codable, Sendable, Equatable {
    public let providerID: String?
    public let accountEmail: String?
    public let accountOrganization: String?
    public let loginMethod: String?

    public init(
        providerID: String? = nil,
        accountEmail: String? = nil,
        accountOrganization: String? = nil,
        loginMethod: String? = nil
    ) {
        self.providerID = providerID
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.loginMethod = loginMethod
    }
}

public struct UsageData: Codable, Sendable, Equatable {
    public let primary: RateWindow?
    public let secondary: RateWindow?
    public let tertiary: RateWindow?
    public let extraRateWindows: [NamedRateWindow]?
    public let accountEmail: String?
    public let accountOrganization: String?
    public let loginMethod: String?
    public let updatedAt: Date?
    public let identity: AccountIdentity?

    public init(
        primary: RateWindow? = nil,
        secondary: RateWindow? = nil,
        tertiary: RateWindow? = nil,
        extraRateWindows: [NamedRateWindow]? = nil,
        accountEmail: String? = nil,
        accountOrganization: String? = nil,
        loginMethod: String? = nil,
        updatedAt: Date? = nil,
        identity: AccountIdentity? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.extraRateWindows = extraRateWindows
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.loginMethod = loginMethod
        self.updatedAt = updatedAt
        self.identity = identity
    }

    enum CodingKeys: String, CodingKey {
        case primary
        case secondary
        case tertiary
        case extraRateWindows
        case accountEmail
        case accountOrganization
        case loginMethod
        case updatedAt
        case identity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primary = try container.decodeIfPresent(RateWindow.self, forKey: .primary)
        self.secondary = try container.decodeIfPresent(RateWindow.self, forKey: .secondary)
        self.tertiary = try container.decodeIfPresent(RateWindow.self, forKey: .tertiary)
        self.extraRateWindows = try container.decodeIfPresent([NamedRateWindow].self, forKey: .extraRateWindows)
        self.accountEmail = try container.decodeIfPresent(String.self, forKey: .accountEmail)
        self.accountOrganization = try container.decodeIfPresent(String.self, forKey: .accountOrganization)
        self.loginMethod = try container.decodeIfPresent(String.self, forKey: .loginMethod)
        self.identity = try container.decodeIfPresent(AccountIdentity.self, forKey: .identity)

        if let date = try? container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            self.updatedAt = date
        } else if let dateStr = try? container.decodeIfPresent(String.self, forKey: .updatedAt) {
            self.updatedAt = ISO8601DateFormatter().date(from: dateStr)
        } else {
            self.updatedAt = nil
        }
    }
}

public struct CodexBarError: Codable, Sendable, Equatable {
    public let message: String
    public let code: Int?
    public let kind: String?

    public init(message: String, code: Int? = nil, kind: String? = nil) {
        self.message = message
        self.code = code
        self.kind = kind
    }
}

public struct CodexBarResponse: Codable, Sendable, Equatable {
    public let provider: String
    public let usage: UsageData?
    public let error: CodexBarError?
    public let version: String?
    public let source: String?

    public init(
        provider: String,
        usage: UsageData? = nil,
        error: CodexBarError? = nil,
        version: String? = nil,
        source: String? = nil
    ) {
        self.provider = provider
        self.usage = usage
        self.error = error
        self.version = version
        self.source = source
    }
}
