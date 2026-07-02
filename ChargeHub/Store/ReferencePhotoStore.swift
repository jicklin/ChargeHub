import Combine
import Foundation

@MainActor
final class ReferencePhotoStore: ObservableObject {
    @Published private(set) var items: [ReferencePhoto]

    struct ImportSummary {
        let total: Int
        let added: Int
        let updated: Int
        let replacedAll: Bool
    }

    enum ImportError: LocalizedError {
        case emptyData

        var errorDescription: String? {
            switch self {
            case .emptyData:
                return "导入文件中没有可用的资料库数据。"
            }
        }
    }

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let usesInMemoryStore: Bool

    init(previewItems: [ReferencePhoto]? = nil) {
        if let previewItems {
            self.items = previewItems
            self.usesInMemoryStore = true
        } else {
            self.items = SharedStorage.loadReferencePhotos()
            self.usesInMemoryStore = false
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var sortedItems: [ReferencePhoto] {
        items.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    func item(withID id: UUID) -> ReferencePhoto? {
        items.first(where: { $0.id == id })
    }

    func addItems(imageDataList: [Data]) {
        let newItems = imageDataList.compactMap { data -> ReferencePhoto? in
            guard !data.isEmpty else { return nil }
            return ReferencePhoto(imageData: data)
        }

        guard !newItems.isEmpty else { return }
        items.insert(contentsOf: newItems, at: 0)
        save()
    }

    func update(_ item: ReferencePhoto) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = ReferencePhoto(
            id: item.id,
            title: item.trimmedTitle,
            notes: item.trimmedNotes,
            category: item.category,
            imageFilename: item.imageFilename,
            imageData: item.imageData,
            createdAt: item.createdAt
        )
        save()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func exportData() throws -> Data {
        try encoder.encode(items)
    }

    func replaceItems(from data: Data) throws -> ImportSummary {
        try replaceItems(from: data, allowEmpty: false)
    }

    func mergeItems(from data: Data) throws -> ImportSummary {
        try mergeItems(from: data, allowEmpty: false)
    }

    func replaceItemsFromSync(from data: Data) throws -> ImportSummary {
        try replaceItems(from: data, allowEmpty: true)
    }

    func mergeItemsFromSync(from data: Data) throws -> ImportSummary {
        try mergeItems(from: data, allowEmpty: true)
    }

    func replaceItemsFromSync(_ importedItems: [ReferencePhoto]) throws -> ImportSummary {
        items = importedItems
        save()
        return ImportSummary(
            total: importedItems.count, added: importedItems.count, updated: 0,
            replacedAll: true)
    }

    func mergeItemsFromSync(_ importedItems: [ReferencePhoto]) throws -> ImportSummary {
        try mergeItems(importedItems: importedItems, allowEmpty: true)
    }

    private func replaceItems(from data: Data, allowEmpty: Bool) throws -> ImportSummary {
        let importedItems = try decodeImportedItems(from: data, allowEmpty: allowEmpty)
        items = importedItems
        save()
        return ImportSummary(
            total: importedItems.count, added: importedItems.count, updated: 0,
            replacedAll: true)
    }

    private func mergeItems(from data: Data, allowEmpty: Bool) throws -> ImportSummary {
        let importedItems = try decodeImportedItems(from: data, allowEmpty: allowEmpty)
        return try mergeItems(importedItems: importedItems, allowEmpty: allowEmpty)
    }

    private func mergeItems(importedItems: [ReferencePhoto], allowEmpty: Bool) throws
        -> ImportSummary
    {
        guard allowEmpty || !importedItems.isEmpty else {
            throw ImportError.emptyData
        }

        var mergedItems = items
        var indexByID = Dictionary(
            uniqueKeysWithValues: mergedItems.enumerated().map { ($0.element.id, $0.offset) })
        var added = 0
        var updated = 0

        for importedItem in importedItems {
            if let index = indexByID[importedItem.id] {
                mergedItems[index] = importedItem
                updated += 1
            } else {
                indexByID[importedItem.id] = mergedItems.count
                mergedItems.append(importedItem)
                added += 1
            }
        }

        items = mergedItems
        save()
        return ImportSummary(
            total: importedItems.count, added: added, updated: updated, replacedAll: false)
    }

    private func decodeImportedItems(from data: Data, allowEmpty: Bool = false) throws
        -> [ReferencePhoto]
    {
        let decoder = JSONDecoder()
        let importedItems = try decoder.decode([ReferencePhoto].self, from: data)

        guard allowEmpty || !importedItems.isEmpty else {
            throw ImportError.emptyData
        }

        return importedItems
    }

    private func save() {
        guard !usesInMemoryStore else { return }

        do {
            try SharedStorage.saveReferencePhotos(items, fileManager: fileManager, encoder: encoder)
        } catch {
            assertionFailure("Failed to save reference photos: \(error.localizedDescription)")
        }
    }
}
