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

    public init(store: UsageStore, onOpenSettings: (() -> Void)? = nil, onQuit: (() -> Void)? = nil) {
        self.store = store
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public static func calculateSizing(store: UsageStore, maxAvailableHeight: CGFloat) -> PanelSizing {
        let configs = store.enabledConfigs
        // Fixed chrome heights:
        // Header: top 10 + text ~15 + bottom 8 = 33pt
        // Top divider: 1pt
        // Scroll content vertical padding: top 10 + bottom 10 = 20pt
        // Bottom divider: 1pt
        // Footer: top 8 + buttons ~15 + bottom 8 = 31pt
        let fixedChromeHeight: CGFloat = 86.0

        if configs.isEmpty {
            let emptyStateHeight: CGFloat = 110.0
            let total = emptyStateHeight + fixedChromeHeight
            return PanelSizing(targetHeight: min(total, maxAvailableHeight), contentHeight: total, needsScroll: false)
        }

        var totalProvidersHeight: CGFloat = 0
        let asAbsolute = store.resetTimeAsAbsolute

        for config in configs {
            let usage = store.usage(for: config.id)
            let windows = usage.normalisedQuotaWindows(config: config, asAbsolute: asAbsolute)

            // Provider identity row (15pt icon / 12.5pt semibold text)
            var sectionHeight: CGFloat = 18.0

            if !windows.isEmpty {
                // 4pt spacing between identity row and quota windows
                sectionHeight += 4.0
                // Each quota window row: title/percent/reset (15pt) + 2pt spacing + 3.5pt bar + 1pt top padding = 21.5pt
                let windowsHeight = CGFloat(windows.count) * 21.5
                // 5pt spacing between multiple windows within the same provider
                let windowsSpacing = CGFloat(max(0, windows.count - 1)) * 5.0
                sectionHeight += windowsHeight + windowsSpacing
            } else if usage.balance == nil && usage.error == nil {
                // "Waiting for usage data…" placeholder
                sectionHeight += 4.0 + 15.0
            }

            // Vertical padding for provider section (1pt top + 1pt bottom)
            sectionHeight += 2.0
            totalProvidersHeight += sectionHeight
        }

        // 10pt spacing between provider sections
        let interProviderSpacing = CGFloat(max(0, configs.count - 1)) * 10.0
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

            // Providers Area (Auto-sized: scroll only when genuinely exceeds screen height)
            ScrollView(.vertical, showsIndicators: sizing.needsScroll) {
                VStack(alignment: .leading, spacing: 10) {
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
                .padding(.vertical, 10)
            }
            .scrollDisabled(!sizing.needsScroll)

            Divider()
                .opacity(0.6)

            // Footer Actions (Pinned)
            footerBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(width: 360, height: sizing.targetHeight)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.96))
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
        let windows = usage.normalisedQuotaWindows(config: config, asAbsolute: store.resetTimeAsAbsolute)

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
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                // Window Title
                Text(window.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .leading)

                // Consumed percentage
                Text("\(Int(window.usedPercent))% used")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Spacer()

                // Prominent Reset Deadline
                if let resetText = window.resetText {
                    Text(resetText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Thin progress bar: grows 0% -> 100% as consumed
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(nsColor: .separatorColor).opacity(0.35))

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor(for: window.usedPercent))
                        .frame(width: geo.size.width * CGFloat(window.usedPercent / 100.0))
                }
            }
            .frame(height: 3.5)
            .padding(.top, 1)
        }
    }

    private func barColor(for percent: Double) -> Color {
        // Understated, factual colors matching Claude Code
        switch percent {
        case ..<50:
            return Color.accentColor.opacity(0.85)
        case 50..<80:
            return Color.orange.opacity(0.9)
        default:
            return Color.red.opacity(0.9)
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.refreshAll() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh All")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)

            Text("•")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Button("Quit") {
                onQuit?()
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
    }
}
