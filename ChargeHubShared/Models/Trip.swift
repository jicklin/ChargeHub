import Foundation

enum TripExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case transport
    case hotel
    case food
    case ticket
    case shopping
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transport: "交通"
        case .hotel: "住宿"
        case .food: "餐饮"
        case .ticket: "门票"
        case .shopping: "购物"
        case .other: "其他"
        }
    }

    var iconName: String {
        switch self {
        case .transport: "car"
        case .hotel: "bed.double"
        case .food: "fork.knife"
        case .ticket: "ticket"
        case .shopping: "bag"
        case .other: "ellipsis.circle"
        }
    }
}

struct TripExpense: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var amount: Decimal
    var category: TripExpenseCategory
    var date: Date
    var notes: String

    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        category: TripExpenseCategory = .other,
        date: Date = .now,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct Trip: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var expenses: [TripExpense]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        destination: String = "",
        startDate: Date = .now,
        endDate: Date = .now,
        notes: String = "",
        expenses: [TripExpense] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.expenses = expenses
        self.createdAt = createdAt
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDestination: String {
        destination.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var totalExpense: Decimal {
        expenses.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var expensesByCategory: [(category: TripExpenseCategory, amount: Decimal)] {
        TripExpenseCategory.allCases.compactMap { category in
            let amount =
                expenses
                .filter { $0.category == category }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return amount > 0 ? (category, amount) : nil
        }
    }

    var dayCount: Int {
        let days =
            Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: startDate),
                to: Calendar.current.startOfDay(for: endDate)
            ).day ?? 0
        return max(days + 1, 1)
    }

    var averageDailyExpense: Decimal {
        guard dayCount > 0 else { return totalExpense }
        return totalExpense / Decimal(dayCount)
    }

    static let previewItems: [Trip] = [
        Trip(
            title: "杭州周末游",
            destination: "杭州",
            startDate: .now,
            endDate: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now,
            expenses: [
                TripExpense(title: "高铁", amount: 268, category: .transport),
                TripExpense(title: "酒店", amount: 820, category: .hotel),
                TripExpense(title: "晚餐", amount: 188, category: .food),
            ]
        )
    ]
}
