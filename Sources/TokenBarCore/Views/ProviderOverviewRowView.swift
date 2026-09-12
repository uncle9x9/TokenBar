import SwiftUI

public struct ProviderOverviewRowView: View {
    public let config: ProviderConfig
    public let usage: ProviderUsage
    public let width: CGFloat

    public init(config: ProviderConfig, usage: ProviderUsage, width: CGFloat = 260) {
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
        HStack(spacing: 8) {
            // Provider icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tintColor.opacity(0.18))
                    .frame(width: 22, height: 22)
                Image(systemName: config.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tintColor)
            }

            // Provider display name
            Text(config.displayName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer()

            // Concise high-value metric
            metricView

            // Disclosure indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var metricView: some View {
        if let err = usage.error, !err.isEmpty {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("Error")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else if let balance = usage.balance {
            Text(balance)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        } else if let remaining = usage.primaryRemainingPercent {
            HStack(spacing: 5) {
                // Mini bar indicator
                miniProgressBar(remaining: remaining)

                Text("\(Int(round(remaining)))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(percentColor(remaining: remaining))
            }
        } else if let used = usage.primaryUsedPercent {
            Text("\(Int(round(used)))% used")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private func miniProgressBar(remaining: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 24, height: 4)
            Capsule()
                .fill(percentColor(remaining: remaining))
                .frame(width: max(2, 24.0 * min(1.0, max(0.0, remaining / 100.0))), height: 4)
        }
    }

    private func percentColor(remaining: Double) -> Color {
        if remaining <= 10.0 {
            return .red
        } else if remaining <= 25.0 {
            return .orange
        } else {
            return .green
        }
    }
}
