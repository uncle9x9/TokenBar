import SwiftUI

public struct SettingsView: View {
    @Bindable var store: UsageStore = UsageStore.shared
    @State private var cliPath: String?
    @State private var detectedSource: String = "None"
    @State private var hasDetectedSource: Bool = false
    @State private var migrationMessage: String?

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

                Toggle("Show Reset Times as Absolute (e.g. Today, 15:30)", isOn: $store.resetTimeAsAbsolute)

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

            Section("Migration & Import") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Previous CodexBarMenuBar Setup")
                                .font(.system(size: 13, weight: .medium))

                            if hasDetectedSource {
                                Text("Found existing settings in \(detectedSource)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No previous configuration file detected")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Import Now") {
                            if let result = store.migrateFromPreviousConfig() {
                                migrationMessage = "✅ Successfully imported \(result.enabledProviderIDs.count) providers from \(result.source)!"
                                StatusItemController.shared.rebuildMenu()
                            } else {
                                migrationMessage = "⚠️ No previous configuration could be imported."
                            }
                        }
                        .disabled(!hasDetectedSource)
                    }

                    if let msg = migrationMessage {
                        Text(msg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(msg.hasPrefix("✅") ? .green : .orange)
                    } else if let lastResult = store.lastMigrationResult {
                        Text("ℹ️ \(lastResult.summary)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
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
                .frame(minHeight: 220)

                HStack {
                    Button("Reset to Defaults") {
                        store.enabledProviderIDs = ProviderConfig.defaultEnabledIDs
                        StatusItemController.shared.rebuildMenu()
                    }

                    Spacer()

                    Button("Load Preview Sample Data") {
                        store.seedSampleData()
                        StatusItemController.shared.rebuildMenu()
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
                    Text("Seamlessly migrates from previous CodexBarMenuBar installations.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 600)
        .task {
            cliPath = await CodexBarCLIBridge.shared.resolvedPath
            let (source, available) = ConfigurationMigrator.detectMigrationSource()
            detectedSource = source
            hasDetectedSource = available
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
                StatusItemController.shared.rebuildMenu()
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
