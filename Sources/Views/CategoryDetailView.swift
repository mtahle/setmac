import SwiftUI
import os.log

private let log = Logger(subsystem: "com.v0id.setmac", category: "CategoryDetail")

struct CategoryDetailView: View {
    let category: ToolCategory
    let state: InstallState
    let bridge: CLIBridge
    @State private var isInstalling = false

    private var tools: [ToolDefinition] {
        state.toolsForCategory(category)
    }

    private var installedCount: Int {
        tools.filter { state.status(for: $0.id).isInstalled }.count
    }

    private var allInstalled: Bool { installedCount == tools.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                categoryBanner

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 0
                ) {
                    ForEach(tools) { tool in
                        VStack(spacing: 0) {
                            ToolCardView(
                                tool: tool,
                                status: state.status(for: tool.id),
                                onInstall: { Task { await install(tool.id) } },
                                onUninstall: { Task { await uninstall(tool.id) } }
                            )
                            .padding(.horizontal, 16)
                            Divider()
                                .padding(.leading, 86)
                        }
                    }
                }

                if !state.logLines.isEmpty {
                    Divider()
                        .padding(.horizontal)
                    LogOutputView(lines: state.logLines, onClear: { state.clearLogs() })
                        .frame(maxHeight: 220)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
        }
        .navigationTitle(category.displayName)
    }

    // MARK: - Banner

    private var categoryBanner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [category.color, category.color.mix(with: .black, by: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle decorative circle
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 160)
                .offset(x: -30, y: 30)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: category.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(category.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("\(tools.count) tools  ·  \(installedCount) installed")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                if isInstalling {
                    ProgressView()
                        .tint(.white)
                        .padding(.bottom, 4)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    // MARK: - Actions

    private func install(_ toolId: String) async {
        log.info("Installing tool: \(toolId)")
        isInstalling = true
        state.isRunning = true
        for await msg in await bridge.install(toolId: toolId) {
            await state.handle(msg, bridge: bridge)
        }
        state.isRunning = false
        isInstalling = false
        log.info("Install finished for: \(toolId)")
    }

    private func uninstall(_ toolId: String) async {
        log.info("Uninstalling tool: \(toolId)")
        isInstalling = true
        state.statuses[toolId] = .uninstalling
        state.isRunning = true
        for await msg in await bridge.uninstall(toolId: toolId) {
            state.applyMessage(msg)
        }
        state.isRunning = false
        isInstalling = false
        log.info("Uninstall finished for: \(toolId)")
    }

    private func installCategory() async {
        log.info("Installing category: \(category.rawValue)")
        isInstalling = true
        state.isRunning = true
        for await msg in await bridge.installCategory(category.rawValue) {
            await state.handle(msg, bridge: bridge)
        }
        state.isRunning = false
        isInstalling = false
        log.info("Category install finished: \(category.rawValue)")
    }
}
