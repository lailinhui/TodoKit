import SwiftUI

struct TodoEditorSheet: View {
    let mode: Mode
    let onSave: (_ title: String, _ note: String, _ groupName: String) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var note: String
    @State private var groupName: String
    @State private var errorMessage: String?
    @FocusState private var focusedField: InputField?

    init(
        mode: Mode,
        initialTitle: String = "",
        initialNote: String = "",
        initialGroupName: String = "",
        onSave: @escaping (_ title: String, _ note: String, _ groupName: String) throws -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _note = State(initialValue: initialNote)
        _groupName = State(initialValue: initialGroupName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode.title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("标题")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(title.count)/30")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("输入待办标题", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .title)
                    .onChange(of: title) { _, newValue in
                        if newValue.count > 30 {
                            title = String(newValue.prefix(30))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("分组（可选）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("例如：工作 / 学习 / 生活", text: $groupName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("备注（可选）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $note)
                    .frame(height: 120)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("取消") {
                    dismiss()
                }

                Button(mode.confirmButtonText) {
                    do {
                        try onSave(title, note, groupName)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 380)
        .onAppear {
            if mode == .add {
                DispatchQueue.main.async {
                    focusedField = .title
                }
            }
        }
    }

    private enum InputField {
        case title
    }

    enum Mode {
        case add
        case edit

        var title: String {
            switch self {
            case .add: return "新增待办"
            case .edit: return "编辑待办"
            }
        }

        var confirmButtonText: String {
            switch self {
            case .add: return "保存"
            case .edit: return "更新"
            }
        }
    }
}
