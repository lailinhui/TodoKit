import SwiftUI

struct CompletedTodosSheet: View {
    @ObservedObject var store: TodoStore
    @Environment(\.dismiss) private var dismiss

    private let limitOptions = [20, 50, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("已完成列表")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                Text("保留数量")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { store.completedHistoryLimit },
                    set: { store.setCompletedHistoryLimit($0) }
                )) {
                    ForEach(limitOptions, id: \.self) { value in
                        Text("\(value)个").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 240)

                Spacer()
            }

            if store.completedItems.isEmpty {
                ContentUnavailableView(
                    "暂无已完成记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("已完成 10 分钟后的待办会进入这里")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.completedItems) { item in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body)
                                    .lineLimit(1)

                                if !item.trimmedNote.isEmpty {
                                    Text(item.trimmedNote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Text(groupTitle(for: item))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Button("恢复") {
                                store.restoreCompletedTodo(id: item.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(18)
        .frame(minWidth: 520, minHeight: 380)
    }

    private func groupTitle(for item: TodoItem) -> String {
        let trimmed = item.groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "分组：未分组" : "分组：\(trimmed)"
    }
}
