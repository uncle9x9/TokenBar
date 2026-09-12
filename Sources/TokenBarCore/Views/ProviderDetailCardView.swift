import SwiftUI

public struct ProviderDetailCardView: View {
    public let config: ProviderConfig
    public let usage: ProviderUsage
    public let width: CGFloat

    public init(config: ProviderConfig, usage: ProviderUsage, width: CGFloat = 280) {
        self.config = config
        self.usage = usage
        self.width = width
    }

    private var asAbsolute: Bool {
        UserDefaults.standard.bool(forKey: "resetTimeAsAbsolute")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Authentic SVG icon + Title + CLI info
            HStack(spacing: 8) {
                if let icon = ProviderIcons.icon(for: config.id, size: 20) {
                    Image(nsImage: icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "app.fill")
                        .font(.body)
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(config.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("codexbar usage --provider \(config.cliName)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                if let err = usage.error, !err.isEmpty {
                    Text("Error")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.red)
                }
            }

            Divider()

            // Normalised Quota Windows (Claude Code model)
            let windows = usage.normalisedQuotaWindows(config: config, asAbsolute: asAbsolute)

            if !windows.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(windows) { window in
                        quotaWindowRow(window)
                    }
                }
            } else if let balance = usage.balance {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(balance)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            } else if let err = usage.error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            } else {
                Text("No usage data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Info Footer
            if usage.accountOrganization != nil || usage.source != nil || usage.lastUpdated != nil {
                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    if let org = usage.accountOrganization, !org.isEmpty {
                        HStack(spacing: 6) {
                            Text("Account")
                                .frame(width: 52, alignment: .leading)
                            Text(org)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    if let source = usage.source, !source.isEmpty {
                        HStack(spacing: 6) {
                            Text("Source")
                                .frame(width: 52, alignment: .leading)
                            Text(source)
                        }
                    }
                    if let date = usage.lastUpdated {
                        HStack(spacing: 6) {
                            Text("Updated")
                                .frame(width: 52, alignment: .leading)
                            Text("\(date, style: .relative) ago")
                        }
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: width, alignment: .leading)
    }

    private func quotaWindowRow(_ window: QuotaWindowItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Line 1: Window / scope label
            Text(window.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            // Line 2: Prominent Reset Deadline on left, Consumed Percentage on far right
            HStack(alignment: .firstTextBaseline) {
                if let resetText = window.resetText {
                    Text(resetText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text("No reset scheduled")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(window.usedPercent))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            // Line 3: Thin progress bar filling left-to-right (0% -> 100% consumed)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: .separatorColor).opacity(0.4))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: window.usedPercent))
                        .frame(width: geo.size.width * CGFloat(window.usedPercent / 100.0))
                }
            }
            .frame(height: 4)
            .padding(.top, 2)
        }
    }

    private func barColor(for percent: Double) -> Color {
        // Clean understated palette matching Claude Code
        switch percent {
        case ..<50:
            return Color.accentColor.opacity(0.85)
        case 50..<80:
            return Color.orange.opacity(0.9)
        default:
            return Color.red.opacity(0.9)
        }
    }
}
