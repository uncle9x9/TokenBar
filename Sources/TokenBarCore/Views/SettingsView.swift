import SwiftUI

public struct SettingsView: View {
    @Bindable var store: UsageStore = UsageStore.shared
    @State private var cliPath: String?

    public init() {}

    public var body: some View {
        Form {
            Section("General") {
                Picker("Refresh Interval", selection: $store.refreshInterval) {
                    Text("1 minute").tag(60.0)
                    Text("2 minutes (Recommended)").tag(120.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                    Text("Manual only").tag(0.0)
                }

                HStack {
                    Text("CodexBar CLI Status")
                    Spacer()
                    if let path = cliPath {
                        Label(path, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 11, design: .monospaced))
                    } else {
                        Label("Not found in standard paths", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 11))
                    }
                }
            }

            Section("Enabled AI Providers (\(store.enabledConfigs.count) active)") {
                List {
                    ForEach(ProviderConfig.allProviders) { config in
                        Toggle(isOn: bindingForProvider(config.id)) {
                            HStack(spacing: 8) {
                                Image(systemName: config.systemImage)
                                    .frame(width: 16)
                                    .foregroundStyle(tintColor(for: config))
                                Text(config.displayName)
                                    .font(.system(size: 13))
                                Spacer()
                                Text(config.cliName)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .frame(minHeight: 240)

                HStack {
                    Button("Reset to Defaults") {
                        store.enabledProviderIDs = ProviderConfig.defaultEnabledIDs
                    }

                    Spacer()

                    Button("Load Preview Sample Data") {
                        store.seedSampleData()
                    }
                }
            }

            Section("About TokenBar") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TokenBar v1.0.0")
                        .font(.headline)
                    Text("One menu-bar icon for all your AI coding quotas.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Designed to preserve menu-bar width around the MacBook Pro notch.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 520)
        .task {
            cliPath = await CodexBarCLIBridge.shared.resolvedPath
        }
    }

    private func bindingForProvider(_ id: String) -> Binding<Bool> {
        Binding(
            get: { store.enabledProviderIDs.contains(id) },
            set: { isEnabled in
                var current = store.enabledProviderIDs
                if isEnabled && !current.contains(id) {
                    current.append(id)
                } else if !isEnabled {
                    current.removeAll { $0 == id }
                }
                store.enabledProviderIDs = current
            }
        )
    }

    private func tintColor(for config: ProviderConfig) -> Color {
        let hex = config.tintHex
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
