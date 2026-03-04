import Combine
import Foundation

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    @Published private(set) var completedItems: [TodoItem] = []
    @Published private(set) var completedHistoryLimit: Int = 20
    @Published private(set) var lastUsedGroupName: String = ""

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let localFileName = "todos.json"
    private let supportedHistoryLimits: Set<Int> = [20, 50, 100]
    private let completedHintShownKey = "todokit.completed.hint.shown"
    private let lastUsedGroupNameKey = "todokit.last.used.group"

    init() {
        lastUsedGroupName = UserDefaults.standard.string(forKey: lastUsedGroupNameKey) ?? ""
        loadFromDisk()
        moveCompletedItemsInMainListIfNeeded()
        if trimCompletedItemsIfNeeded() {
            persist()
        }
    }

    func addTodo(title: String, note: String, groupName: String) throws {
        let normalizedTitle = try Self.normalizedTitle(from: title)
        let normalizedGroupName = Self.normalizedGroupName(from: groupName)
        let now = Date()

        let item = TodoItem(
            title: normalizedTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            groupName: normalizedGroupName,
            createdAt: now,
            updatedAt: now,
            completedAt: nil
        )

        lastUsedGroupName = normalizedGroupName
        UserDefaults.standard.set(normalizedGroupName, forKey: lastUsedGroupNameKey)
        items.insert(item, at: 0)
        persist()
    }

    func updateTodo(id: UUID, title: String, note: String, groupName: String) throws {
        let normalizedTitle = try Self.normalizedTitle(from: title)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        items[index].title = normalizedTitle
        items[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].groupName = Self.normalizedGroupName(from: groupName)
        items[index].updatedAt = Date()

        persist()
    }

    func deleteTodo(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func deleteTodo(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            items.remove(at: index)
        }
        persist()
    }

    func moveTodosInDisplayGroup(_ displayGroupName: String, from source: IndexSet, to destination: Int) {
        var ids = items
            .filter { canonicalDisplayGroupName(for: $0.groupName) == displayGroupName && !$0.isCompleted }
            .map(\.id)

        moveArray(&ids, from: source, to: destination)
        reorderTodosInDisplayGroup(displayGroupName, orderedIDs: ids)
    }

    func canMoveTodo(id: UUID, inDisplayGroup displayGroupName: String, direction: Int) -> Bool {
        let ids = items
            .filter { canonicalDisplayGroupName(for: $0.groupName) == displayGroupName && !$0.isCompleted }
            .map(\.id)

        guard let currentIndex = ids.firstIndex(of: id) else { return false }
        let nextIndex = currentIndex + direction
        return ids.indices.contains(nextIndex)
    }

    func moveTodo(id: UUID, inDisplayGroup displayGroupName: String, direction: Int) {
        var ids = items
            .filter { canonicalDisplayGroupName(for: $0.groupName) == displayGroupName && !$0.isCompleted }
            .map(\.id)

        guard let currentIndex = ids.firstIndex(of: id) else { return }
        let nextIndex = currentIndex + direction
        guard ids.indices.contains(nextIndex) else { return }

        ids.swapAt(currentIndex, nextIndex)
        reorderTodosInDisplayGroup(displayGroupName, orderedIDs: ids)
    }

    @discardableResult
    func toggleCompletion(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }

        if items[index].isCompleted {
            items[index].completedAt = nil
            items[index].updatedAt = Date()
            persist()
            return false
        }

        var item = items.remove(at: index)
        item.completedAt = Date()
        item.updatedAt = Date()

        completedItems.insert(item, at: 0)
        trimCompletedItemsIfNeeded()
        persist()
        return markCompletedHintAsShownIfNeeded()
    }

    func moveCompletedItemsInMainListIfNeeded() {
        var movedItems: [TodoItem] = []

        items.removeAll { item in
            guard item.completedAt != nil else { return false }
            movedItems.append(item)
            return true
        }

        guard !movedItems.isEmpty else {
            return
        }

        movedItems.sort {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }
        completedItems.insert(contentsOf: movedItems, at: 0)
        trimCompletedItemsIfNeeded()
        persist()
    }

    func restoreCompletedTodo(id: UUID) {
        guard let index = completedItems.firstIndex(where: { $0.id == id }) else {
            return
        }

        var item = completedItems.remove(at: index)
        item.completedAt = nil
        item.updatedAt = Date()

        items.insert(item, at: 0)
        persist()
    }

    func deleteCompletedTodo(id: UUID) {
        completedItems.removeAll { $0.id == id }
        persist()
    }

    func setCompletedHistoryLimit(_ limit: Int) {
        completedHistoryLimit = normalizedCompletedHistoryLimit(limit)
        _ = trimCompletedItemsIfNeeded()
        persist()
    }

    private static func normalizedTitle(from rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TodoValidationError.emptyTitle
        }
        guard trimmed.count <= 30 else {
            throw TodoValidationError.titleTooLong
        }

        return trimmed
    }

    private static func normalizedGroupName(from rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedCompletedHistoryLimit(_ rawValue: Int) -> Int {
        supportedHistoryLimits.contains(rawValue) ? rawValue : 20
    }

    private func canonicalDisplayGroupName(for rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.ungroupedDisplayName : trimmed
    }

    private func reorderTodosInDisplayGroup(_ displayGroupName: String, orderedIDs: [UUID]) {
        guard !orderedIDs.isEmpty else { return }

        let groupItems = items.filter { canonicalDisplayGroupName(for: $0.groupName) == displayGroupName && !$0.isCompleted }
        guard !groupItems.isEmpty else { return }

        let byID = Dictionary(uniqueKeysWithValues: groupItems.map { ($0.id, $0) })
        let reorderedGroupItems = orderedIDs.compactMap { byID[$0] }
        guard reorderedGroupItems.count == groupItems.count else { return }

        var reorderedIterator = reorderedGroupItems.makeIterator()
        items = items.map { item in
            guard canonicalDisplayGroupName(for: item.groupName) == displayGroupName, !item.isCompleted else {
                return item
            }
            return reorderedIterator.next() ?? item
        }

        persist()
    }

    private func markCompletedHintAsShownIfNeeded() -> Bool {
        if UserDefaults.standard.bool(forKey: completedHintShownKey) {
            return false
        }

        UserDefaults.standard.set(true, forKey: completedHintShownKey)
        return true
    }

    private var localFileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = root.appendingPathComponent("TodoKit", isDirectory: true)

        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        return folder.appendingPathComponent(localFileName)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: localFileURL) else { return }

        guard let snapshot = try? decoder.decode(TodoSnapshot.self, from: data) else { return }
        items = snapshot.items
        completedItems = snapshot.completedItems.sorted {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }
        completedHistoryLimit = normalizedCompletedHistoryLimit(snapshot.completedHistoryLimit)
    }

    private func persist() {
        let snapshot = TodoSnapshot(
            items: items,
            completedItems: completedItems,
            completedHistoryLimit: completedHistoryLimit,
            modifiedAt: Date()
        )
        saveToDisk(snapshot)
    }

    @discardableResult
    private func trimCompletedItemsIfNeeded() -> Bool {
        let before = completedItems.count
        if completedItems.count > completedHistoryLimit {
            completedItems = Array(completedItems.prefix(completedHistoryLimit))
        }

        return completedItems.count != before
    }

    private func saveToDisk(_ snapshot: TodoSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: localFileURL, options: .atomic)
    }

    private func moveArray(_ array: inout [UUID], from source: IndexSet, to destination: Int) {
        let moving = source.sorted().map { array[$0] }
        for index in source.sorted(by: >) {
            array.remove(at: index)
        }

        let target = min(max(destination, 0), array.count)
        array.insert(contentsOf: moving, at: target)
    }

    private static let ungroupedDisplayName = "未分组"
}
