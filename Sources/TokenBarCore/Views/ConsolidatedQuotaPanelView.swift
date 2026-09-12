import SwiftUI
import AppKit

public struct PanelSizing: Equatable, Sendable {
    public let targetHeight: CGFloat
    public let contentHeight: CGFloat
    public let needsScroll: Bool

    public init(targetHeight: CGFloat, contentHeight: CGFloat, needsScroll: Bool) {
        self.targetHeight = targetHeight
        self.contentHeight = contentHeight
        self.needsScroll = needsScroll
    }
}

public struct ConsolidatedQuotaPanelView: View {
    @Bindable var store: UsageStore
    public var onOpenSettings: (() -> Void)?
    public var onQuit: (() -> Void)?
    public var onHoverChanged: ((Bool) -> Void)?

    public init(
        store: UsageStore,
        onOpenSettings: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil,
        onHoverChanged: ((Bool) -> Void)? = nil
    ) {
        self.store = store
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.onHoverChanged = onHoverChanged
    }

    public static func calculateSizing(store: UsageStore, maxAvailableHeight: CGFloat) -> PanelSizing {
        let configs = store.enabledConfigs
        // Fixed chrome heights:
        // Header: top 10 + text ~15 + bottom 8 = 33pt
        // Top divider: 1pt
        // Scroll content vertical padding: top 12 + bottom 14 = 26pt
        // Bottom divider: 1pt
        // Footer: top 8 + buttons ~16 + bottom 8 = 32pt
        // Extra bottom breathing clearance: 12pt
        let fixedChromeHeight: CGFloat = 105.0

        if configs.isEmpty {
            let emptyStateHeight: CGFloat = 110.0
            let total = emptyStateHeight + fixedChromeHeight
            return PanelSizing(targetHeight: min(total, maxAvailableHeight), contentHeight: total, needsScroll: false)
        }

        var totalProvidersHeight: CGFloat = 0
        let asAbsolute = store.resetTimeAsAbsolute

        for config in configs {
            let usage = store.usage(for: config.id)
            let windows = usage.normalisedQuotaWindows(config: config, asAbsolute: asAbsolute, countdownForFiveHourLimits: store.countdownForFiveHourLimits)

            // Provider identity row (15pt icon / 12.5pt semibold text)
            var sectionHeight: CGFloat = 18.0

            if !windows.isEmpty {
                // 5pt spacing between identity row and quota windows
                sectionHeight += 5.0
                // Each quota window row: title/percent/reset (15pt) + 3pt spacing + 6pt bar + 1pt top padding = 25pt
                let windowsHeight = CGFloat(windows.count) * 25.0
                // 6pt spacing between multiple windows within the same provider
                let windowsSpacing = CGFloat(max(0, windows.count - 1)) * 6.0
                sectionHeight += windowsHeight + windowsSpacing
            } else if usage.balance == nil && usage.error == nil {
                // "Waiting for usage data…" placeholder
                sectionHeight += 5.0 + 15.0
            }

            // Vertical padding for provider section (1pt top + 1pt bottom)
            sectionHeight += 2.0
            totalProvidersHeight += sectionHeight
        }

        // 12pt spacing between provider sections
        let interProviderSpacing = CGFloat(max(0, configs.count - 1)) * 12.0
        let rawContentHeight = totalProvidersHeight + interProviderSpacing + fixedChromeHeight

        let targetHeight = min(rawContentHeight, maxAvailableHeight)
        let needsScroll = rawContentHeight > (maxAvailableHeight + 1.0)

        return PanelSizing(
            targetHeight: ceil(targetHeight),
            contentHeight: ceil(rawContentHeight),
            needsScroll: needsScroll
        )
    }

    public var body: some View {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let maxAllowedHeight = max(380, screenHeight - 70)
        let sizing = Self.calculateSizing(store: store, maxAvailableHeight: maxAllowedHeight)

        VStack(spacing: 0) {
            // Header Bar (Pinned)
            headerBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.6)

            // Providers Area (Auto-sized: natural scrolling without lock)
            ScrollView(.vertical, showsIndicators: sizing.needsScroll) {
                VStack(alignment: .leading, spacing: 12) {
                    let configs = store.enabledConfigs
                    if configs.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(configs) { config in
                            providerSection(config: config)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
            }

            Divider()
                .opacity(0.6)

            // Footer Actions (Pinned)
            footerBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(width: 360, height: sizing.targetHeight)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        .onHover { isHovered in
            onHoverChanged?(isHovered)
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("TOKENBAR")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(.secondary)

            Text("•")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Text("\(store.enabledConfigs.count) providers")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if store.isRefreshing {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Refreshing…")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if let lastTime = store.lastRefreshTime {
                Text("Updated \(ResetTimeFormatter.relativeUpdatedDescription(from: lastTime))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Provider Section
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("No providers enabled")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Button("Configure Providers…") {
                onOpenSettings?()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 30)
    }

    @ViewBuilder
    private func providerSection(config: ProviderConfig) -> some View {
        let usage = store.usage(for: config.id)
        let windows = usage.normalisedQuotaWindows(config: config, asAbsolute: store.resetTimeAsAbsolute, countdownForFiveHourLimits: store.countdownForFiveHourLimits)

        VStack(alignment: .leading, spacing: 4) {
            // Provider Identity Row
            HStack(spacing: 7) {
                if let icon = ProviderIcons.icon(for: config.id, size: 15) {
                    Image(nsImage: icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "app.fill")
                        .frame(width: 15, height: 15)
                }

                Text(config.displayName)
                    .font(.system(size: 12.5, weight: .semibold))

                Spacer()

                if let b = usage.balance {
                    Text(b)
                        .font(.system(size: 11.5, weight: .semibold))
                        .monospacedDigit()
                } else if let err = usage.error {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }

                ProviderStatusDot(usage: usage, isEnabled: true)
            }

            // Normalised Quota Windows (Level 1 Immediate Glancability)
            if !windows.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(windows) { w in
                        quotaWindowRow(w)
                    }
                }
                .padding(.leading, 22)
            } else if usage.balance == nil && usage.error == nil {
                Text("Waiting for usage data…")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 22)
            }
        }
        .padding(.vertical, 1)
    }

    // MARK: - Quota Window Row (Claude Code Model)
    private func quotaWindowRow(_ window: QuotaWindowItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                // Window Title (Left)
                Text(window.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                // Prominent Reset Deadline (Right)
                if let resetText = window.resetText {
                    Text(resetText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                // Consumed percentage (Far right, matching Claude Code)
                Text("\(Int(window.usedPercent))%")
                    .font(.system(size: 11.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 32, alignment: .trailing)
            }

            // Quota progress bar: grows 0% -> 100% as consumed (Claude Code model)
            // Full track is always clearly visible even at 0%
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.14))

                    if window.usedPercent > 0 {
                        Capsule(style: .continuous)
                            .fill(barColor(for: window.usedPercent))
                            .frame(width: min(geo.size.width, max(6.0, geo.size.width * CGFloat(window.usedPercent / 100.0))))
                    }
                }
            }
            .frame(height: 6)
            .padding(.top, 1)
        }
    }

    private func barColor(for percent: Double) -> Color {
        // Understated, factual colors matching Claude Code
        switch percent {
        case ..<50:
            return Color.accentColor
        case 50..<80:
            return Color.orange
        default:
            return Color.red
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 8) {
            Button {
                Task { await store.refreshAll() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh All")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(FooterActionButtonStyle())
            .disabled(store.isRefreshing)

            Spacer()

            Button {
                onOpenSettings?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("Settings…")
                }
                .font(.system(size: 11))
            }
            .buttonStyle(FooterActionButtonStyle())

            Text("•")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Button("Quit") {
                onQuit?()
            }
            .font(.system(size: 11))
            .buttonStyle(FooterActionButtonStyle())
        }
        .foregroundStyle(.secondary)
    }
}

public struct FooterActionButtonStyle: ButtonStyle {
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.primary : (isHovered ? Color.primary : Color.secondary))
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}
