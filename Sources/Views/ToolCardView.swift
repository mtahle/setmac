import SwiftUI

/// App Store–style horizontal row. Designed to sit in a 2-column LazyVGrid.
struct ToolCardView: View {
    let tool: ToolDefinition
    let status: ToolStatus
    let onInstall: () -> Void
    var onUninstall: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            ToolIconView(tool: tool, status: status, size: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(tool.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(tool.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                statusTag
            }

            Spacer(minLength: 8)

            // fixedSize() prevents the button from being squished and wrapping
            actionBadge
                .fixedSize()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Small status tag shown below description

    @ViewBuilder
    private var statusTag: some View {
        switch status {
        case .installed(let version):
            if let v = version {
                Text(v)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        case .installing:
            Text("Installing…")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .uninstalling:
            Text("Uninstalling…")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .checking:
            Text("Checking…")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .error(let msg):
            Text(msg)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        case .notInstalled, .unknown:
            EmptyView()
        }
    }

    // MARK: - Right-side action

    @ViewBuilder
    private var actionBadge: some View {
        switch status {
        case .installed:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)

                if let onUninstall {
                    Button(action: onUninstall) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Uninstall \(tool.name)")
                }
            }

        case .notInstalled:
            Button(action: onInstall) {
                Text("GET")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
                    .frame(minWidth: 62)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

        case .installing, .uninstalling, .checking:
            ProgressView()
                .controlSize(.small)
                .frame(width: 62)

        case .error:
            Button(action: onInstall) {
                Text("Retry")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(minWidth: 62)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.tertiary)
                .frame(width: 62)
                .help("Status unknown — refresh to check")
        }
    }
}
