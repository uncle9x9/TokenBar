import Foundation

public struct ExtraWindowUsage: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let usedPercent: Double
    public let resetsAt: Date?
    public let windowMinutes: Int?

    public init(id: String, title: String, usedPercent: Double, resetsAt: Date? = nil, windowMinutes: Int? = nil) {
        self.id = id
        self.title = title
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.windowMinutes = windowMinutes
    }

    public var remainingPercent: Double {
        max(0, 100.0 - usedPercent)
    }
}

public struct QuotaWindowItem: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let usedPercent: Double
    public let resetsAt: Date?
    public let resetText: String?

    public init(id: String, title: String, usedPercent: Double, resetsAt: Date?, asAbsolute: Bool = false) {
        self.id = id
        self.title = title
        self.usedPercent = max(0, min(100.0, usedPercent))
        self.resetsAt = resetsAt
        if let resetsAt {
            self.resetText = ResetTimeFormatter.resetLine(date: resetsAt, asAbsolute: asAbsolute)
        } else {
            self.resetText = nil
        }
    }
}

public struct ProviderUsage: Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var sessionPercent: Double?
    public var sessionWindowMinutes: Int?
    public var sessionResetsAt: Date?
    public var weeklyPercent: Double?
    public var weeklyWindowMinutes: Int?
    public var weeklyResetsAt: Date?
    public var extraWindows: [ExtraWindowUsage] = []
    public var balance: String?
    public var accountEmail: String?
    public var accountOrganization: String?
    public var loginMethod: String?
    public var source: String?
    public var lastUpdated: Date?
    public var error: String?

    public init(
        id: String,
        displayName: String,
        sessionPercent: Double? = nil,
        sessionWindowMinutes: Int? = nil,
        sessionResetsAt: Date? = nil,
        weeklyPercent: Double? = nil,
        weeklyWindowMinutes: Int? = nil,
        weeklyResetsAt: Date? = nil,
        extraWindows: [ExtraWindowUsage] = [],
        balance: String? = nil,
        accountEmail: String? = nil,
        accountOrganization: String? = nil,
        loginMethod: String? = nil,
        source: String? = nil,
        lastUpdated: Date? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.sessionPercent = sessionPercent
        self.sessionWindowMinutes = sessionWindowMinutes
        self.sessionResetsAt = sessionResetsAt
        self.weeklyPercent = weeklyPercent
        self.weeklyWindowMinutes = weeklyWindowMinutes
        self.weeklyResetsAt = weeklyResetsAt
        self.extraWindows = extraWindows
        self.balance = balance
        self.accountEmail = accountEmail
        self.accountOrganization = accountOrganization
        self.loginMethod = loginMethod
        self.source = source
        self.lastUpdated = lastUpdated
        self.error = error
    }

    /// Primary display percentage: consumed percentage in the primary window.
    public var primaryUsedPercent: Double? {
        sessionPercent ?? weeklyPercent
    }

    public var primaryRemainingPercent: Double? {
        guard let p = primaryUsedPercent else { return nil }
        return max(0, 100.0 - p)
    }

    public var primaryResetsAt: Date? {
        sessionResetsAt ?? weeklyResetsAt
    }

    public var isConnected: Bool {
        error == nil && (sessionPercent != nil || weeklyPercent != nil || balance != nil)
    }

    public var isExhausted: Bool {
        if let s = sessionPercent, s >= 100.0 { return true }
        if let w = weeklyPercent, w >= 100.0 { return true }
        return false
    }

    public var statusDescription: String {
        if let err = error, !err.isEmpty {
            return "Error"
        }
        if isExhausted {
            return "Exhausted"
        }
        if isConnected {
            return "Connected"
        }
        return "No Data"
    }

    public static func empty(config: ProviderConfig) -> ProviderUsage {
        ProviderUsage(id: config.id, displayName: config.displayName)
    }

    /// Normalises quota windows across all providers into the Claude Code behavioural model:
    /// Window / scope, reset time, and consumed percentage.
    public func normalisedQuotaWindows(config: ProviderConfig, asAbsolute: Bool = false) -> [QuotaWindowItem] {
        var items: [QuotaWindowItem] = []

        if config.id == "antigravity" && !extraWindows.isEmpty {
            for extra in extraWindows {
                items.append(QuotaWindowItem(
                    id: extra.id,
                    title: extra.title,
                    usedPercent: extra.usedPercent,
                    resetsAt: extra.resetsAt,
                    asAbsolute: asAbsolute
                ))
            }
            return items
        }

        if let s = sessionPercent {
            let label: String
            if config.id == "claude" {
                label = "5-hour limit"
            } else if sessionWindowMinutes == 300 {
                label = "5-hour"
            } else if config.id == "grok" {
                if let resetsAt = sessionResetsAt {
                    let duration = resetsAt.timeIntervalSince(Date())
                    let days = Int((duration / 86400.0).rounded(.toNearestOrAwayFromZero))
                    if (4...12).contains(days) || sessionWindowMinutes == nil {
                        label = "Weekly"
                    } else if (20...45).contains(days) {
                        label = "Monthly"
                    } else if sessionWindowMinutes == 300 {
                        label = "5-hour"
                    } else {
                        label = "Credits"
                    }
                } else {
                    label = "Credits"
                }
            } else {
                label = "Session"
            }
            items.append(QuotaWindowItem(
                id: "session",
                title: label,
                usedPercent: s,
                resetsAt: sessionResetsAt,
                asAbsolute: asAbsolute
            ))
        }

        if let w = weeklyPercent {
            let label: String
            if config.id == "claude" {
                label = "Weekly · all models"
            } else if config.id == "grok" {
                label = "On-demand"
            } else {
                label = "Weekly"
            }
            items.append(QuotaWindowItem(
                id: "weekly",
                title: label,
                usedPercent: w,
                resetsAt: weeklyResetsAt,
                asAbsolute: asAbsolute
            ))
        }

        for extra in extraWindows {
            var title = extra.title
            if config.id == "claude" && title.lowercased().contains("fable") {
                title = "Weekly · Fable"
            }
            items.append(QuotaWindowItem(
                id: extra.id,
                title: title,
                usedPercent: extra.usedPercent,
                resetsAt: extra.resetsAt,
                asAbsolute: asAbsolute
            ))
        }

        return items
    }
}
