import SwiftUI

public struct ProviderDetailCardView: View {
    public let config: ProviderConfig
    public let usage: ProviderUsage
    public let width: CGFloat

    public init(config: ProviderConfig, usage: ProviderUsage, width: CGFloat = 270) {
        self.config = config
        self.usage = usage
        self.width = width
    }

    private var tintColor: Color {
        let hex = config.tintHex
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Identity + Status Badge
            headerSection

            Divider()

            // Quota progress bars
            if hasAnyQuotaBars {
                quotaBarsSection
                Divider()
            } else if let balance = usage.balance {
                balanceSection(balance: balance)
                Divider()
            }

            // Error or warning banner if present
            if let err = usage.error, !err.isEmpty {
                errorBanner(message: err)
                Divider()
            }

            // Metadata: Reset countdown, updated time, source, account
            metadataSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: width, alignment: .leading)
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tintColor.opacity(0.18))
                    .frame(width: 24, height: 24)
                Image(systemName: config.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tintColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(config.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tintColor)
                    .tracking(0.5)

                if let source = usage.source, !source.isEmpty {
                    Text(source)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status Badge
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(usage.statusDescription)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        if usage.error != nil {
            return .red
        } else if usage.isExhausted {
            return .orange
        } else if usage.isConnected {
            return .green
        } else {
            return .gray
        }
    }

    // MARK: - Quota Progress Bars
    private var hasAnyQuotaBars: Bool {
        usage.sessionPercent != nil || usage.weeklyPercent != nil || !usage.extraWindows.isEmpty
    }

    private var quotaBarsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Current / Session window
            if let sessionUsed = usage.sessionPercent {
                let remaining = max(0, 100.0 - sessionUsed)
                progressBarRow(
                    title: "Current",
                    usedPercent: sessionUsed,
                    remainingPercent: remaining,
                    windowMinutes: usage.sessionWindowMinutes
                )
            }

            // Weekly window
            if let weeklyUsed = usage.weeklyPercent {
                let remaining = max(0, 100.0 - weeklyUsed)
                progressBarRow(
                    title: "Weekly",
                    usedPercent: weeklyUsed,
                    remainingPercent: remaining,
                    windowMinutes: usage.weeklyWindowMinutes
                )
            }

            // Extra provider-specific windows (e.g. Opus, Code Review)
            ForEach(usage.extraWindows) { extra in
                progressBarRow(
                    title: extra.title,
                    usedPercent: extra.usedPercent,
                    remainingPercent: extra.remainingPercent,
                    windowMinutes: extra.windowMinutes
                )
            }
        }
    }

    private func progressBarRow(
        title: String,
        usedPercent: Double,
        remainingPercent: Double,
        windowMinutes: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.primary)

                if let windowMinutes, windowMinutes > 0 {
                    Text(formatWindowMinutes(windowMinutes))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text("\(Int(round(remainingPercent)))% remaining")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(barColor(remainingPercent: remainingPercent))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(barColor(remainingPercent: remainingPercent))
                        .frame(width: max(3, geo.size.width * min(1.0, max(0.0, remainingPercent / 100.0))))
                }
            }
            .frame(height: 6)
        }
    }

    private func balanceSection(balance: String) -> some View {
        HStack {
            Text("Balance")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(balance)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(6)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Metadata Rows
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Reset countdown or absolute description
            if let resetDate = usage.primaryResetsAt {
                let resetText = UsageStore.shared.resetTimeAsAbsolute
                    ? ResetTimeFormatter.absoluteDescription(from: resetDate)
                    : ResetTimeFormatter.countdownDescription(from: resetDate)
                metaKeyValueRow(
                    label: "Reset",
                    value: resetText
                )
            }

            // Last Updated
            if let updated = usage.lastUpdated {
                metaKeyValueRow(
                    label: "Updated",
                    value: ResetTimeFormatter.relativeUpdatedDescription(from: updated)
                )
            }

            // Source
            if let source = usage.source, !source.isEmpty {
                metaKeyValueRow(label: "Source", value: source)
            }

            // Account / Org
            if let email = usage.accountEmail, !email.isEmpty {
                metaKeyValueRow(label: "Account", value: email)
            } else if let org = usage.accountOrganization, !org.isEmpty {
                metaKeyValueRow(label: "Organization", value: org)
            }
        }
    }

    private func metaKeyValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private func barColor(remainingPercent: Double) -> Color {
        if remainingPercent <= 10.0 {
            return .red
        } else if remainingPercent <= 25.0 {
            return .orange
        } else {
            return tintColor
        }
    }

    private func formatWindowMinutes(_ minutes: Int) -> String {
        if minutes >= 1440 {
            let days = minutes / 1440
            return "(\(days)d window)"
        }
        if minutes >= 60 {
            let hours = minutes / 60
            return "(\(hours)h window)"
        }
        return "(\(minutes)m window)"
    }
}
