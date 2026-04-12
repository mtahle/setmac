import SwiftUI

struct OverviewView: View {
    let state: InstallState
    let bridge: CLIBridge
    @Binding var selection: SidebarItem?
    @State private var isInstalling = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroCard
                    .padding(.horizontal)

                ForEach(state.categories) { category in
                    CategoryRow(
                        category: category,
                        state: state,
                        onSeeAll: { selection = .category(category) },
                        onInstall: { toolId in Task { await install(toolId) } }
                    )
                }

                if !state.logLines.isEmpty {
                    LogOutputView(lines: state.logLines, onClear: { state.clearLogs() })
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await refresh() }
                }
                .disabled(state.isRunning)
                .help("Refresh tool installation status")
            }
        }
        .navigationTitle("Overview")
    }

    // MARK: - Hero card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Dynamic mesh gradient — colors reflect which categories are most installed
            meshBackground
                .animation(.easeInOut(duration: 1.2), value: state.installedCount)

            VStack(alignment: .leading, spacing: 8) {
                if let manifest = state.manifest {
                    Text(manifest.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(manifest.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }

                Spacer().frame(height: 4)

                HStack(spacing: 10) {
                    ProgressView(
                        value: Double(state.installedCount),
                        total: Double(max(state.totalTools, 1))
                    )
                    .tint(.white)
                    .frame(maxWidth: 140)

                    Text("\(state.installedCount) / \(state.totalTools)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))

                    if state.isRunning {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                    }
                }

                // Per-category mini progress pills
                categoryPills
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 206)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: meshPrimaryColor.opacity(0.32), radius: 22, y: 6)
    }

    // MARK: - Mesh gradient (data-driven)

    @ViewBuilder
    private var meshBackground: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1), .init(0.5, 1), .init(1, 1),
            ],
            colors: meshColors
        )
    }

    /// Three colors pulled from the most-installed categories, mixed to form 9 mesh points.
    private var meshColors: [Color] {
        let sorted = state.categories.sorted { installRatio(for: $0) > installRatio(for: $1) }

        let c1 = (sorted.first?.color ?? .blue).mix(with: .black, by: 0.18)
        let c2 = (sorted.dropFirst().first?.color ?? .indigo).mix(with: .black, by: 0.24)
        let c3 = (sorted.dropFirst(2).first?.color ?? .purple).mix(with: .black, by: 0.28)

        return [
            c1,                         c1.mix(with: c2, by: 0.5),    c2,
            c1.mix(with: c3, by: 0.35), c2.mix(with: c1, by: 0.3),   c2.mix(with: c3, by: 0.35),
            c3.mix(with: c1, by: 0.2),  c3.mix(with: c2, by: 0.3),   c3,
        ]
    }

    private func installRatio(for category: ToolCategory) -> Double {
        let tools = state.toolsForCategory(category)
        guard !tools.isEmpty else { return 0 }
        return Double(tools.filter { state.status(for: $0.id).isInstalled }.count) / Double(tools.count)
    }

    private var meshPrimaryColor: Color {
        state.categories.max(by: { installRatio(for: $0) < installRatio(for: $1) })?.color ?? .blue
    }

    // MARK: - Category breakdown pills

    @ViewBuilder
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(state.categories) { category in
                    let tools = state.toolsForCategory(category)
                    let installed = tools.filter { state.status(for: $0.id).isInstalled }.count
                    if !tools.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.caption2)
                            Text("\(installed)/\(tools.count)")
                                .font(.caption2.monospacedDigit())
                        }
                        .foregroundStyle(.white.opacity(installed == tools.count ? 1.0 : 0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            .white.opacity(installed == tools.count ? 0.28 : 0.12),
                            in: Capsule()
                        )
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Actions

    private func refresh() async {
        state.isRunning = true
        for await msg in await bridge.checkAllStatuses() {
            state.applyMessage(msg)
        }
        state.isRunning = false
    }

    private func installAll() async {
        isInstalling = true
        state.isRunning = true
        for await msg in await bridge.installAll() {
            await state.handle(msg, bridge: bridge)
        }
        state.isRunning = false
        isInstalling = false
    }

    private func install(_ toolId: String) async {
        state.isRunning = true
        for await msg in await bridge.install(toolId: toolId) {
            await state.handle(msg, bridge: bridge)
        }
        state.isRunning = false
    }
}

// MARK: - Category row

private struct CategoryRow: View {
    let category: ToolCategory
    let state: InstallState
    let onSeeAll: () -> Void
    let onInstall: (String) -> Void

    private var tools: [ToolDefinition] {
        state.toolsForCategory(category)
    }

    private var installedCount: Int {
        tools.filter { state.status(for: $0.id).isInstalled }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .font(.callout)
                Text(category.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                Text("·  \(installedCount)/\(tools.count)")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Spacer()
                Button("See All", action: onSeeAll)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // 2-column responsive grid — up to 6 tools in overview, See All for the rest
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 0
            ) {
                ForEach(tools.prefix(6)) { tool in
                    VStack(spacing: 0) {
                        ToolCardView(
                            tool: tool,
                            status: state.status(for: tool.id),
                            onInstall: { onInstall(tool.id) }
                        )
                        .padding(.horizontal, 16)
                        Divider()
                            .padding(.leading, 86)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
