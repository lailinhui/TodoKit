import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store = TodoStore()
    @StateObject private var loginManager = LoginLaunchManager()

    @State private var sheetState: SheetState?
    @State private var errorMessage: String?
    @State private var showCompletedHint: Bool = false
    @State private var expandedGroups: Set<String> = []
    @State private var knownGroups: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                ContentUnavailableView(
                    "还没有待办项",
                    systemImage: "checklist",
                    description: Text("点击右上角 + 创建你的第一条待办")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedItems, id: \.groupName) { group in
                        Section {
                            if expandedGroups.contains(group.groupName) {
                                ForEach(group.items) { item in
                                    TodoRowView(
                                        item: item,
                                        onToggle: {
                                            let shouldShowHint = store.toggleCompletion(id: item.id)
                                            if shouldShowHint {
                                                showCompletedHint = true
                                            }
                                        },
                                        onMoveUp: {
                                            store.moveTodo(id: item.id, inDisplayGroup: group.groupName, direction: -1)
                                        },
                                        onMoveDown: {
                                            store.moveTodo(id: item.id, inDisplayGroup: group.groupName, direction: 1)
                                        },
                                        canMoveUp: store.canMoveTodo(id: item.id, inDisplayGroup: group.groupName, direction: -1),
                                        canMoveDown: store.canMoveTodo(id: item.id, inDisplayGroup: group.groupName, direction: 1),
                                        onEdit: {
                                            sheetState = .edit(item)
                                        },
                                        onDelete: {
                                            store.deleteTodo(id: item.id)
                                        }
                                    )
                                    .contextMenu {
                                        Button("新增待办") {
                                            sheetState = .add
                                        }
                                    }
                                }
                            }
                        } header: {
                            Button {
                                toggleGroup(group.groupName)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: expandedGroups.contains(group.groupName) ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(group.groupName)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.inset)
                .textSelection(.enabled)
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    sheetState = .add
                } label: {
                    Label("新增", systemImage: "plus")
                }
                .help("新增待办")

                Button {
                    sheetState = .completed
                } label: {
                    Label("已完成", systemImage: "checkmark.circle")
                }
                .help("查看已完成列表")

                Menu {
                    Toggle(
                        "开机自动启动",
                        isOn: Binding(
                            get: { loginManager.isEnabled },
                            set: { newValue in
                                if let message = loginManager.setEnabled(newValue) {
                                    errorMessage = message
                                }
                            }
                        )
                    )
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
        .sheet(item: $sheetState) { state in
            switch state {
            case .add:
                TodoEditorSheet(mode: .add, initialGroupName: store.lastUsedGroupName) { title, note, groupName in
                    try store.addTodo(title: title, note: note, groupName: groupName)
                }
            case .edit(let item):
                TodoEditorSheet(
                    mode: .edit,
                    initialTitle: item.title,
                    initialNote: item.note,
                    initialGroupName: item.groupName
                ) { title, note, groupName in
                    try store.updateTodo(id: item.id, title: title, note: note, groupName: groupName)
                }
            case .completed:
                CompletedTodosSheet(store: store)
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("提示", isPresented: $showCompletedHint) {
            Button("知道了", role: .cancel) {}
            Button("去查看") {
                sheetState = .completed
            }
        } message: {
            Text("已完成的待办会进入“已完成”列表，你可以在那里查看或恢复。")
        }
        .contextMenu {
            Button("新增待办") {
                sheetState = .add
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.moveCompletedItemsInMainListIfNeeded()
        }
        .onAppear {
            store.moveCompletedItemsInMainListIfNeeded()
            syncGroupExpansionState()
        }
        .onChange(of: store.items) { _, _ in
            syncGroupExpansionState()
        }
    }

    private var groupedItems: [(groupName: String, items: [TodoItem])] {
        let grouped = Dictionary(grouping: store.items) { item in
            normalizedGroupName(item.groupName)
        }

        let sortedGroups = grouped.keys.sorted { lhs, rhs in
            if lhs == Self.ungroupedGroupName { return true }
            if rhs == Self.ungroupedGroupName { return false }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        return sortedGroups.map { groupName in
            (groupName: groupName, items: grouped[groupName] ?? [])
        }
    }

    private func normalizedGroupName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.ungroupedGroupName : trimmed
    }

    private func toggleGroup(_ groupName: String) {
        if expandedGroups.contains(groupName) {
            expandedGroups.remove(groupName)
        } else {
            expandedGroups.insert(groupName)
        }
    }

    private func syncGroupExpansionState() {
        let currentGroups = Set(groupedItems.map(\.groupName))
        let newGroups = currentGroups.subtracting(knownGroups)

        expandedGroups.formUnion(newGroups)
        expandedGroups.formIntersection(currentGroups)
        knownGroups = currentGroups
    }

    private static let ungroupedGroupName = "未分组"
}

private enum SheetState: Identifiable {
    case add
    case edit(TodoItem)
    case completed

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let item):
            return "edit-\(item.id.uuidString)"
        case .completed:
            return "completed"
        }
    }
}

#Preview {
    ContentView()
}
