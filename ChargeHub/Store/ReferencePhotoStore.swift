import Combine
import Foundation

@MainActor
final class ReferencePhotoStore: ObservableObject {
    @Published private(set) var items: [ReferencePhoto]

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
            imageData: item.imageData,
            createdAt: item.createdAt
        )
        save()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
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
