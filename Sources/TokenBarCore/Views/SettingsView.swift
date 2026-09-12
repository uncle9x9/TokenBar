import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Settings Tab

public enum SettingsTab: String, CaseIterable, Sendable {
    case general, providers, about

    public var label: String {
        switch self {
        case .general: return "General"
        case .providers: return "Providers"
        case .about: return "About"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .providers: return "square.grid.2x2"
        case .about: return "info.circle"
        }
    }

    public static let defaultWidth: CGFloat = 546
    public static let providersWidth: CGFloat = 792
    public static let windowHeight: CGFloat = 638

    public var preferredWidth: CGFloat {
        self == .providers ? Self.providersWidth : Self.defaultWidth
    }

    public var preferredHeight: CGFloat {
        Self.windowHeight
    }
}

// MARK: - Reusable: SettingsSection

public struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey?
    let caption: LocalizedStringKey?
    let contentSpacing: CGFloat
    @ViewBuilder let content: () -> Content

    public init(title: LocalizedStringKey? = nil, caption: LocalizedStringKey? = nil, spacing: CGFloat = 14, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.caption = caption
        self.contentSpacing = spacing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: contentSpacing) {
                content()
            }
        }
    }
}

// MARK: - Reusable: PreferenceToggleRow

public struct PreferenceToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @Binding var isOn: Bool

    public init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: $isOn) {
                Text(title).font(.body)
            }
            .toggleStyle(.checkbox)

            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Reusable: ProviderSettingsSection

public struct ProviderSettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let spacing: CGFloat
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat
    @ViewBuilder let content: () -> Content

    public init(title: LocalizedStringKey, spacing: CGFloat = 12, verticalPadding: CGFloat = 10, horizontalPadding: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.spacing = spacing
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - Main Settings View

public struct SettingsView: View {
    @State private var store = UsageStore.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var contentWidth: CGFloat = SettingsTab.defaultWidth
    @State private var contentHeight: CGFloat = SettingsTab.windowHeight

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(store: store)
                .tabItem { Label(SettingsTab.general.label, systemImage: SettingsTab.general.icon) }
                .tag(SettingsTab.general)

            ProvidersSettingsView(store: store)
                .tabItem { Label(SettingsTab.providers.label, systemImage: SettingsTab.providers.icon) }
                .tag(SettingsTab.providers)

            AboutSettingsView()
                .tabItem { Label(SettingsTab.about.label, systemImage: SettingsTab.about.icon) }
                .tag(SettingsTab.about)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: contentWidth, height: contentHeight)
        .onAppear {
            updateLayout(for: selectedTab, animate: false)
        }
        .onChange(of: selectedTab) { _, newTab in
            updateLayout(for: newTab, animate: true)
        }
    }

    private func updateLayout(for tab: SettingsTab, animate: Bool) {
        let change = {
            self.contentWidth = tab.preferredWidth
            self.contentHeight = tab.preferredHeight
        }
        if animate {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { change() }
        } else {
            change()
        }
        Self.resizeSettingsWindow(width: tab.preferredWidth, height: tab.preferredHeight, animate: animate)
    }

    private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"
    private static let knownTabTitles = Set(SettingsTab.allCases.map(\.label))

    private static func resizeSettingsWindow(width: CGFloat, height: CGFloat, animate: Bool) {
        guard let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == settingsWindowIdentifier
                || knownTabTitles.contains($0.title)
                || $0.title.contains("TokenBar Settings")
        }) else { return }
        let toolbarHeight = window.frame.height - window.contentLayoutRect.height
        guard toolbarHeight > 0 else { return }
        let newSize = NSSize(width: width, height: height + toolbarHeight)
        var frame = window.frame
        frame.origin.y += frame.size.height - newSize.height
        frame.size = newSize
        window.setFrame(frame, display: true, animate: animate)
    }
}

// MARK: - General Tab

public struct GeneralSettingsView: View {
    @Bindable var store: UsageStore

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showUsageAsUsed") private var showUsageAsUsed = true
    @AppStorage("resetTimeAsAbsolute") private var resetTimeAsAbsolute = false
    @AppStorage("colorPercentText") private var colorPercentText = true
    @AppStorage("colorCountdownText") private var colorCountdownText = true
    @AppStorage("quotaNotifEnabled") private var quotaNotifEnabled = false
    @AppStorage("quotaNotifWarningThreshold") private var quotaNotifWarningThreshold: Double = 80
    @AppStorage("quotaNotifCriticalThreshold") private var quotaNotifCriticalThreshold: Double = 95
    @AppStorage("showThresholdTicks") private var showThresholdTicks = true
    @AppStorage("showWorkdayMarkers") private var showWorkdayMarkers = true
    @AppStorage("batterySaverEnabled") private var batterySaverEnabled = false
    @AppStorage("menuBarPresentation") private var menuBarPresentation: String = MenuBarPresentation.automatic.rawValue
    @AppStorage("autoConsolidateThreshold") private var autoConsolidateThreshold: Int = 4

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(title: "System") {
                    PreferenceToggleRow(
                        "Start at Login",
                        subtitle: "Automatically launch TokenBar when you log in.",
                        isOn: $launchAtLogin
                    )
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLoginHelper.setEnabled(enabled)
                    }
                }

                Divider()

                SettingsSection(title: "Automation") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("Refresh cadence")
                                .font(.subheadline.weight(.semibold))

                            Picker("", selection: $store.refreshInterval) {
                                Text("Manual").tag(0.0)
                                Text("1 min").tag(60.0)
                                Text("2 min").tag(120.0)
                                Text("5 min").tag(300.0)
                                Text("15 min").tag(900.0)
                                Text("30 min").tag(1800.0)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 200)
                            .controlSize(.small)

                            Spacer(minLength: 0)
                        }

                        Text("How often TokenBar polls providers in the background.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                SettingsSection(title: "Menu Bar Presentation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Presentation Mode", selection: $menuBarPresentation) {
                            Text("Automatic (1–3 Horizontal, 4+ Consolidated)").tag(MenuBarPresentation.automatic.rawValue)
                            Text("Horizontal / Original (Classic CodexBarMenuBar)").tag(MenuBarPresentation.horizontal.rawValue)
                            Text("Vertical / Single Icon").tag(MenuBarPresentation.vertical.rawValue)
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: menuBarPresentation) { _, newMode in
                            if let p = MenuBarPresentation(rawValue: newMode) {
                                store.presentation = p
                                StatusItemController.shared.rebuildMenu()
                            }
                        }

                        if menuBarPresentation == MenuBarPresentation.automatic.rawValue {
                            HStack(spacing: 8) {
                                Text("Consolidate when enabled providers ≥")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Stepper("\(autoConsolidateThreshold)", value: $autoConsolidateThreshold, in: 2...10)
                                    .controlSize(.small)
                                    .onChange(of: autoConsolidateThreshold) { _, val in
                                        store.autoConsolidateThreshold = val
                                        StatusItemController.shared.rebuildMenu()
                                    }
                            }
                            .padding(.leading, 20)
                            .padding(.top, 2)
                        }

                        Text("Consolidated vertical mode keeps a single compact icon in the menu bar to prevent crowding around the MacBook Pro display notch.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                SettingsSection(title: "Display") {
                    PreferenceToggleRow(
                        "Show usage as used",
                        subtitle: "Progress bars fill as you consume quota (instead of showing remaining).",
                        isOn: $showUsageAsUsed
                    )

                    PreferenceToggleRow(
                        "Show reset time as clock",
                        subtitle: "Display reset times as absolute clock values instead of countdowns.",
                        isOn: $resetTimeAsAbsolute
                    )
                    .onChange(of: resetTimeAsAbsolute) { _, val in
                        store.resetTimeAsAbsolute = val
                    }

                    PreferenceToggleRow(
                        "Color percentage text",
                        subtitle: "Tint the percentage number by usage (green when low, red when high).",
                        isOn: $colorPercentText
                    )

                    PreferenceToggleRow(
                        "Color countdown time",
                        subtitle: "Tint the countdown text by time remaining.",
                        isOn: $colorCountdownText
                    )

                    PreferenceToggleRow(
                        "Show threshold ticks on bars",
                        subtitle: "Draw small tick marks at warning and critical thresholds on usage bars.",
                        isOn: $showThresholdTicks
                    )

                    PreferenceToggleRow(
                        "Show workday markers on weekly bars",
                        subtitle: "Add subtle vertical marks on weekly usage bars to show day boundaries.",
                        isOn: $showWorkdayMarkers
                    )
                }

                Divider()

                SettingsSection(title: "CodexBarMenuBar Migration") {
                    VStack(alignment: .leading, spacing: 6) {
                        let sourceInfo = ConfigurationMigrator.detectMigrationSource()
                        if sourceInfo.available {
                            HStack {
                                Text("Detected configuration from: \(sourceInfo.source)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Re-import Settings") {
                                    ConfigurationMigrator.performMigration()
                                    StatusItemController.shared.rebuildMenu()
                                }
                                .controlSize(.small)
                            }
                        } else {
                            Text("CodexBarMenuBar configuration has been imported or standard defaults are active.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Providers Tab

public struct ProvidersSettingsView: View {
    @Bindable var store: UsageStore
    @State private var selectedID: String?

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ProviderSidebarView(
                store: store,
                selectedID: $selectedID
            )

            if let id = selectedID ?? store.orderedProviderConfigs.first?.id,
               let config = ProviderConfig.byID[id] {
                ProviderDetailView(config: config, store: store)
            } else {
                ContentUnavailableView(
                    "Select a Provider",
                    systemImage: "square.grid.2x2",
                    description: Text("Choose a provider from the list to configure.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear {
            if selectedID == nil {
                selectedID = store.orderedProviderConfigs.first?.id
            }
        }
    }
}

// MARK: - Provider Sidebar

public struct ProviderSidebarView: View {
    @Bindable var store: UsageStore
    @Binding var selectedID: String?
    @State private var draggingProvider: String?
    @State private var searchText: String = ""

    private var visibleConfigs: [ProviderConfig] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.orderedProviderConfigs }
        return store.orderedProviderConfigs.filter {
            $0.displayName.lowercased().contains(q) || $0.id.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search providers", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(visibleConfigs) { config in
                        ProviderSidebarRowView(
                            config: config,
                            isSelected: selectedID == config.id,
                            store: store
                        )
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedID == config.id
                                      ? Color(nsColor: .selectedContentBackgroundColor)
                                      : Color.clear)
                                .padding(.horizontal, 4)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = config.id }
                        .onDrag {
                            draggingProvider = config.id
                            return NSItemProvider(object: config.id as NSString)
                        }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: ProviderDropDelegate(
                                item: config.id,
                                providerOrder: $store.providerOrder,
                                dragging: $draggingProvider
                            )
                        )
                    }
                    if visibleConfigs.isEmpty {
                        Text("No matches")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 24)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        )
        .frame(minWidth: 240, maxWidth: 240)
    }
}

// MARK: - Provider Sidebar Row

public struct ProviderSidebarRowView: View {
    let config: ProviderConfig
    let isSelected: Bool
    @Bindable var store: UsageStore

    private var isEnabled: Bool {
        store.enabledIDSet.contains(config.id)
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ProviderSidebarReorderHandle()
                .padding(.vertical, 4)
                .padding(.horizontal, 2)

            if let icon = ProviderIcons.icon(for: config.id, size: 18) {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isSelected ? .white : .primary)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(config.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)

                    ProviderStatusDot(
                        usage: store.usages[config.id],
                        isEnabled: isEnabled
                    )
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { enabled in
                    if enabled {
                        if !store.enabledProviderIDs.contains(config.id) {
                            store.enabledProviderIDs.append(config.id)
                        }
                    } else {
                        store.enabledProviderIDs.removeAll { $0 == config.id }
                    }
                    StatusItemController.shared.rebuildMenu()
                }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .controlSize(.small)
        }
        .padding(.vertical, 3)
    }

    private var statusText: String {
        guard isEnabled else { return "Disabled" }
        guard let usage = store.usages[config.id] else { return "No data" }
        if let err = usage.error { return err }
        if let s = usage.sessionPercent {
            if let w = usage.weeklyPercent {
                return "\(Int(s))% · W:\(Int(w))%"
            }
            return "\(Int(s))%"
        }
        if let b = usage.balance { return b }
        return "OK"
    }
}

// MARK: - Sidebar Reorder Handle

public struct ProviderSidebarReorderHandle: View {
    public var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    Circle().frame(width: 2, height: 2)
                    Circle().frame(width: 2, height: 2)
                }
            }
        }
        .frame(width: 12, height: 12)
        .foregroundStyle(.tertiary)
    }
}

// MARK: - Status Dot

public struct ProviderStatusDot: View {
    let usage: ProviderUsage?
    let isEnabled: Bool

    public var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 6, height: 6)
    }

    private var dotColor: Color {
        guard isEnabled else { return .gray }
        guard let usage else { return .gray }
        if usage.error != nil { return .red }
        if let s = usage.sessionPercent {
            if s >= 95 { return .red }
            if s >= 80 { return .orange }
            if s >= 50 { return .yellow }
            return .green
        }
        if usage.balance != nil { return .green }
        return .gray
    }
}

// MARK: - Provider Drop Delegate

public struct ProviderDropDelegate: DropDelegate {
    let item: String
    @Binding var providerOrder: [String]
    @Binding var dragging: String?

    public func dropEntered(info: DropInfo) {
        guard let dragging, dragging != item else { return }
        guard let fromIndex = providerOrder.firstIndex(of: dragging),
              let toIndex = providerOrder.firstIndex(of: item)
        else { return }
        if fromIndex == toIndex { return }
        withAnimation(.default) {
            providerOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    public func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    public func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

// MARK: - Provider Detail View

public struct ProviderDetailView: View {
    let config: ProviderConfig
    @Bindable var store: UsageStore

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { store.enabledIDSet.contains(config.id) },
            set: { enabled in
                if enabled {
                    if !store.enabledProviderIDs.contains(config.id) {
                        store.enabledProviderIDs.append(config.id)
                    }
                } else {
                    store.enabledProviderIDs.removeAll { $0 == config.id }
                }
                StatusItemController.shared.rebuildMenu()
            }
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                providerHeader

                providerInfoGrid

                if let usage = store.usages[config.id], isEnabled.wrappedValue {
                    currentUsageSection(usage)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var providerHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                if let icon = ProviderIcons.icon(for: config.id, size: 28) {
                    Image(nsImage: icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "app.fill")
                        .font(.title2)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.displayName)
                        .font(.title3.weight(.semibold))
                    Text("codexbar usage --provider \(config.cliName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task {
                        await store.refreshProvider(id: config.id)
                        StatusItemController.shared.rebuildMenu()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isRefreshing)

                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    private var providerInfoGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("State").frame(width: 80, alignment: .leading)
                Text(isEnabled.wrappedValue ? "Enabled" : "Disabled")
            }
            GridRow {
                Text("CLI Name").frame(width: 80, alignment: .leading)
                Text(config.cliName)
            }
            GridRow {
                Text("Type").frame(width: 80, alignment: .leading)
                Text(config.displayType == .usageBar ? "Subscription (Usage)" : "Balance (Credit)")
            }
            if let usage = store.usages[config.id] {
                if let org = usage.accountOrganization {
                    GridRow {
                        Text("Account").frame(width: 80, alignment: .leading)
                        Text(org).lineLimit(1).truncationMode(.tail)
                    }
                }
                if let source = usage.source, source != "auto" {
                    GridRow {
                        Text("Source").frame(width: 80, alignment: .leading)
                        Text(source)
                    }
                }
                if let date = usage.lastUpdated {
                    GridRow {
                        Text("Updated").frame(width: 80, alignment: .leading)
                        Text("\(date, style: .relative) ago")
                    }
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func currentUsageSection(_ usage: ProviderUsage) -> some View {
        ProviderSettingsSection(title: "Usage & Menu Bar Display", spacing: 10, verticalPadding: 6, horizontalPadding: 0) {
            if let s = usage.sessionPercent {
                usageMetricRow(windowKey: "session", label: "Session", percent: s, resetsAt: usage.sessionResetsAt)
            }
            if let w = usage.weeklyPercent {
                usageMetricRow(windowKey: "weekly", label: "Weekly", percent: w, resetsAt: usage.weeklyResetsAt)
            }
            ForEach(usage.extraWindows) { extra in
                usageMetricRow(windowKey: extra.id, label: extra.title, percent: extra.usedPercent, resetsAt: extra.resetsAt)
            }
            if let b = usage.balance {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("Balance")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 60, alignment: .leading)
                        Text(b)
                            .font(.footnote)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 2)
            }
            if let err = usage.error {
                HStack(alignment: .top, spacing: 10) {
                    Text("Error")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 60, alignment: .leading)
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func usageMetricRow(windowKey: String, label: String, percent: Double, resetsAt: Date? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 60, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progressColor(percent))
                                .frame(width: geo.size.width * min(CGFloat(percent) / 100, 1.0))
                        }
                    }
                    .frame(minWidth: 220, maxWidth: .infinity)
                    .frame(height: 8)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(Int(percent))% used")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer(minLength: 8)
                        if let resetText = ResetTimeFormatter.resetLine(date: resetsAt, asAbsolute: store.resetTimeAsAbsolute) {
                            Text(resetText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    private func progressColor(_ percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case 50..<80: return .yellow
        case 80..<95: return .orange
        default: return .red
        }
    }
}

// MARK: - About Tab

public struct AboutSettingsView: View {
    @State private var iconHover = false

    private var appIcon: NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApplication.shared.applicationIconImage
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(iconHover ? 1.05 : 1.0)
                .shadow(color: iconHover ? .accentColor.opacity(0.25) : .clear, radius: 6)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        iconHover = hovering
                    }
                }

            VStack(spacing: 2) {
                Text("TokenBar")
                    .font(.title3)
                    .bold()
                Text("Version 1.0.0")
                    .foregroundStyle(.secondary)
                Text("Presentation extension for CodexBarMenuBar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .center, spacing: 8) {
                Link("View TokenBar on GitHub", destination: URL(string: "https://github.com/uncle9x9/TokenBar")!)
                Link("CodexBarMenuBar Upstream", destination: URL(string: "https://github.com/Lobobodev/CodexBarMenuBar")!)
                Link("Powered by CodexBar CLI", destination: URL(string: "https://github.com/steipete/CodexBar")!)
            }
            .font(.footnote)
            .padding(.top, 8)

            Divider()

            VStack(spacing: 4) {
                Text("Data source")
                    .font(.footnote.weight(.semibold))
                Text("/opt/homebrew/bin/codexbar")
                    .font(.footnote)
                    .monospaced()
                    .foregroundStyle(.secondary)
            }

            Text("© 2026 TokenBar Authors. MIT License.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Launch at Login Helper

public enum LaunchAtLoginHelper {
    public static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }
}
