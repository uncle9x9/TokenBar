import SwiftUI
import AppKit

public struct ConsolidatedQuotaPanelView: View {
    @Bindable var store: UsageStore
    public var onOpenSettings: (() -> Void)?
    public var onQuit: (() -> Void)?

    public init(store: UsageStore, onOpenSettings: (() -> Void)? = nil, onQuit: (() -> Void)? = nil) {
        self.store = store
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .opacity(0.6)

            // Providers Scrollable Area (Level 1: ALL providers immediately visible)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
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
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 460)

            Divider()
                .opacity(0.6)

            // Footer Actions
            footerBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 350)
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

        VStack(alignment: .leading, spacing: 6) {
            // Provider Identity Row
            HStack(spacing: 8) {
                if let icon = ProviderIcons.icon(for: config.id, size: 16) {
                    Image(nsImage: icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "app.fill")
                        .frame(width: 16, height: 16)
                }

                Text(config.displayName)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                if let b = usage.balance {
                    Text(b)
                        .font(.system(size: 12, weight: .semibold))
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
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(windows) { w in
                        quotaWindowRow(w)
                    }
                }
                .padding(.leading, 24)
            } else if usage.balance == nil && usage.error == nil {
                Text("Waiting for usage data…")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Quota Window Row (Claude Code Model)
    private func quotaWindowRow(_ window: QuotaWindowItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                // Window Title
                Text(window.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80, alignment: .leading)

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
