import Foundation

enum LifeReminderKind: String, CaseIterable, Codable, Identifiable {
    case event
    case birthday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .event: "事件"
        case .birthday: "生日"
        }
    }

    var iconName: String {
        switch self {
        case .event: "calendar.badge.clock"
        case .birthday: "birthday.cake"
        }
    }
}

enum LifeReminderState: Equatable {
    case overdue(days: Int)
    case dueToday
    case upcoming(daysRemaining: Int)
    case future(daysRemaining: Int)
}

struct LifeReminder: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var kind: LifeReminderKind
    var date: Date
    var advanceNoticeDays: Int
    var notes: String
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        kind: LifeReminderKind,
        date: Date,
        advanceNoticeDays: Int = 3,
        notes: String = "",
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.date = date
        self.advanceNoticeDays = advanceNoticeDays
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var repeatsAnnually: Bool {
        kind == .birthday
    }

    func nextOccurrence(referenceDate: Date = .now, calendar: Calendar = .current) -> Date {
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let originalDay = calendar.startOfDay(for: date)

        guard repeatsAnnually else {
            return originalDay
        }

        let components = calendar.dateComponents([.month, .day], from: originalDay)
        let referenceYear = calendar.component(.year, from: referenceDay)
        var nextComponents = DateComponents()
        nextComponents.year = referenceYear
        nextComponents.month = components.month
        nextComponents.day = components.day

        let thisYear = calendar.date(from: nextComponents) ?? originalDay
        if thisYear >= referenceDay {
            return thisYear
        }

        nextComponents.year = referenceYear + 1
        return calendar.date(from: nextComponents) ?? thisYear
    }

    func daysUntil(referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: referenceDate)
        let end = nextOccurrence(referenceDate: referenceDate, calendar: calendar)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func reminderState(referenceDate: Date = .now, calendar: Calendar = .current)
        -> LifeReminderState
    {
        let days = daysUntil(referenceDate: referenceDate, calendar: calendar)

        if days < 0 {
            return .overdue(days: abs(days))
        }
        if days == 0 {
            return .dueToday
        }
        if days <= advanceNoticeDays {
            return .upcoming(daysRemaining: days)
        }
        return .future(daysRemaining: days)
    }

    var displayDateText: String {
        Self.chineseDateFormatter.string(from: date)
    }

    func occurrenceDateText(referenceDate: Date = .now, calendar: Calendar = .current) -> String {
        Self.chineseDateFormatter.string(
            from: nextOccurrence(referenceDate: referenceDate, calendar: calendar))
    }

    static let previewItems: [LifeReminder] = [
        LifeReminder(
            title: "去医院体检",
            kind: .event,
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 14))
                ?? .now,
            advanceNoticeDays: 7,
            notes: "带身份证，早上空腹"
        ),
        LifeReminder(
            title: "妈妈生日",
            kind: .birthday,
            date: Calendar.current.date(from: DateComponents(year: 1968, month: 9, day: 3)) ?? .now,
            advanceNoticeDays: 14
        ),
    ]

    private static let chineseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = .autoupdatingCurrent
        formatter.dateFormat = "y年M月d日"
        return formatter
    }()
}
