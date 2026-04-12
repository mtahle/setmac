import SwiftUI

struct SearchResultsView: View {
    let query: String
    let state: InstallState
    let bridge: CLIBridge

    private var results: [(tool: ToolDefinition, category: ToolCategory)] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return state.manifest?.tools.compactMap { tool in
            guard
                tool.name.lowercased().contains(q) ||
                tool.description.lowercased().contains(q) ||
                tool.id.lowercased().contains(q),
                let cat = ToolCategory(rawValue: tool.category)
            else { return nil }
            return (tool, cat)
        } ?? []
    }

    var body: some View {
        Group {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 0
                    ) {
                        ForEach(results, id: \.tool.id) { item in
                            VStack(spacing: 0) {
                                ToolCardView(
                                    tool: item.tool,
                                    status: state.status(for: item.tool.id),
                                    onInstall: { Task { await install(item.tool.id) } },
                                    onUninstall: { Task { await uninstall(item.tool.id) } }
                                )
                                .padding(.horizontal, 16)
                                Divider()
                                    .padding(.leading, 86)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Results for \"\(query)\"")
    }

    private func install(_ toolId: String) async {
        state.isRunning = true
        for await msg in await bridge.install(toolId: toolId) {
            await state.handle(msg, bridge: bridge)
        }
        state.isRunning = false
    }

    private func uninstall(_ toolId: String) async {
        state.statuses[toolId] = .uninstalling
        state.isRunning = true
        for await msg in await bridge.uninstall(toolId: toolId) {
            state.applyMessage(msg)
        }
        state.isRunning = false
    }

    // TODO: add search debounce if tool count grows beyond ~150
}
