import SwiftUI
import AppKit

/// Displays a tool's icon: real app icon when the .app is installed, else a colored SF Symbol tile.
struct ToolIconView: View {
    let tool: ToolDefinition
    let status: ToolStatus
    let size: CGFloat

    @State private var appIcon: NSImage? = nil

    var body: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                symbolTile
            }
        }
        .task(id: tool.id) {
            appIcon = await resolveAppIcon()
        }
    }

    // MARK: - SF Symbol fallback

    private var symbolTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(tool.swiftColor.opacity(0.13))
                .frame(width: size, height: size)
            Image(systemName: tool.icon)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(tool.swiftColor)
        }
    }

    // MARK: - NSWorkspace icon resolution

    private func resolveAppIcon() async -> NSImage? {
        guard status.isInstalled, let path = tool.check?.path, path.hasSuffix(".app") else {
            return nil
        }
        // Expand tilde and env-style prefixes
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: expanded)
        // Reject the generic "unknown file" icon (it's always exactly 32×32 from NSWorkspace for missing apps)
        let s = icon.size
        guard s.width > 32 || s.height > 32 else { return nil }
        return icon
    }
}

