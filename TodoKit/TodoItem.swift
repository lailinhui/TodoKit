import Foundation

struct TodoItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var note: String
    var groupName: String
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        note: String,
        groupName: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.groupName = groupName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case note
        case groupName
        case group
        case createdAt
        case updatedAt
        case completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decode(String.self, forKey: .note)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
            ?? (try container.decodeIfPresent(String.self, forKey: .group))
            ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(note, forKey: .note)
        try container.encode(groupName, forKey: .groupName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
    }
}

struct TodoSnapshot: Codable {
    var items: [TodoItem]
    var completedItems: [TodoItem]
    var completedHistoryLimit: Int
    var modifiedAt: Date

    init(
        items: [TodoItem],
        completedItems: [TodoItem] = [],
        completedHistoryLimit: Int = 20,
        modifiedAt: Date = Date()
    ) {
        self.items = items
        self.completedItems = completedItems
        self.completedHistoryLimit = completedHistoryLimit
        self.modifiedAt = modifiedAt
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case completedItems
        case completedHistoryLimit
        case modifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([TodoItem].self, forKey: .items)
        completedItems = try container.decodeIfPresent([TodoItem].self, forKey: .completedItems) ?? []
        completedHistoryLimit = try container.decodeIfPresent(Int.self, forKey: .completedHistoryLimit) ?? 20
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
    }
}

enum TodoValidationError: LocalizedError {
    case emptyTitle
    case titleTooLong

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "标题不能为空。"
        case .titleTooLong:
            return "标题长度不能超过 30 个字符。"
        }
    }
}
