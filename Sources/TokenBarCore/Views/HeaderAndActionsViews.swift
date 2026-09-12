import SwiftUI

public struct MenuHeaderView: View {
    public let store: UsageStore
    public let width: CGFloat

    public init(store: UsageStore, width: CGFloat = 260) {
        self.store = store
        self.width = width
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.needle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.tint)

            Text("TokenBar")
                .font(.system(size: 13, weight: .bold))

            Text("\(store.enabledConfigs.count) providers")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else if let last = store.lastRefreshTime {
                Text(ResetTimeFormatter.relativeUpdatedDescription(from: last))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: width, alignment: .leading)
    }
}
