import Combine
import Foundation

@MainActor
final class TripStore: ObservableObject {
    @Published private(set) var trips: [Trip]

    struct ImportSummary {
        let total: Int
        let added: Int
        let updated: Int
        let replacedAll: Bool
    }

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let usesInMemoryStore: Bool

    init(previewTrips: [Trip]? = nil) {
        if let previewTrips {
            self.trips = previewTrips
            self.usesInMemoryStore = true
        } else {
            self.trips = SharedStorage.loadTrips(fileManager: fileManager)
            self.usesInMemoryStore = false
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var sortedTrips: [Trip] {
        trips.sorted { $0.startDate > $1.startDate }
    }

    var totalExpense: Decimal {
        trips.reduce(Decimal(0)) { $0 + $1.totalExpense }
    }

    var expensesByCategory: [(category: TripExpenseCategory, amount: Decimal)] {
        TripExpenseCategory.allCases.compactMap { category in
            let amount =
                trips
                .flatMap(\.expenses)
                .filter { $0.category == category }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return amount > 0 ? (category, amount) : nil
        }
    }

    func trip(withID id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    func addTrip(_ trip: Trip) {
        trips.append(trip)
        save()
    }

    func updateTrip(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index] = trip
        save()
    }

    func deleteTrip(id: UUID) {
        trips.removeAll { $0.id == id }
        save()
    }

    func addExpense(_ expense: TripExpense, to tripID: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].expenses.append(expense)
        save()
    }

    func updateExpense(_ expense: TripExpense, in tripID: UUID) {
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripID }),
            let expenseIndex = trips[tripIndex].expenses.firstIndex(where: { $0.id == expense.id })
        else { return }
        trips[tripIndex].expenses[expenseIndex] = expense
        save()
    }

    func deleteExpense(id: UUID, in tripID: UUID) {
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[tripIndex].expenses.removeAll { $0.id == id }
        save()
    }

    func exportData() throws -> Data {
        try encoder.encode(trips)
    }

    func replaceTripsFromSync(from data: Data) throws -> ImportSummary {
        let imported = try decodeTrips(from: data)
        trips = imported
        save()
        return ImportSummary(
            total: imported.count, added: imported.count, updated: 0, replacedAll: true)
    }

    func mergeTripsFromSync(from data: Data) throws -> ImportSummary {
        let imported = try decodeTrips(from: data)
        var merged = trips
        var indexByID = Dictionary(
            uniqueKeysWithValues: merged.enumerated().map { ($0.element.id, $0.offset) })
        var added = 0
        var updated = 0

        for trip in imported {
            if let index = indexByID[trip.id] {
                merged[index] = trip
                updated += 1
            } else {
                indexByID[trip.id] = merged.count
                merged.append(trip)
                added += 1
            }
        }

        trips = merged
        save()
        return ImportSummary(
            total: imported.count, added: added, updated: updated, replacedAll: false)
    }

    private func decodeTrips(from data: Data) throws -> [Trip] {
        try JSONDecoder().decode([Trip].self, from: data)
    }

    private func save() {
        guard !usesInMemoryStore else { return }

        do {
            try SharedStorage.saveTrips(trips, fileManager: fileManager, encoder: encoder)
        } catch {
            assertionFailure("Failed to save trips: \(error.localizedDescription)")
        }
    }
}
