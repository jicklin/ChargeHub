import Foundation

enum ReminderState: Equatable {
    case overdue(days: Int)
    case dueToday
    case upcoming(daysRemaining: Int)
    case normal(daysRemaining: Int)
}

struct Device: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var category: DeviceCategory
    var lastChargedAt: Date
    var lastChargeLevel: Int?
    var remindAfterDays: Int
    var notes: String
    var isArchived: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: DeviceCategory,
        lastChargedAt: Date,
        lastChargeLevel: Int? = nil,
        remindAfterDays: Int,
        notes: String = "",
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.lastChargedAt = lastChargedAt
        self.lastChargeLevel = lastChargeLevel
        self.remindAfterDays = remindAfterDays
        self.notes = notes
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    func daysSinceCharge(referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: lastChargedAt)
        let end = calendar.startOfDay(for: referenceDate)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    func reminderState(referenceDate: Date = .now, calendar: Calendar = .current) -> ReminderState {
        let days = daysSinceCharge(referenceDate: referenceDate, calendar: calendar)
        let remaining = remindAfterDays - days

        if remaining < 0 {
            return .overdue(days: abs(remaining))
        }

        if remaining == 0 {
            return .dueToday
        }

        if remaining <= 3 {
            return .upcoming(daysRemaining: remaining)
        }

        return .normal(daysRemaining: remaining)
    }

    var chargeLevelText: String {
        guard let lastChargeLevel else { return "未记录" }
        return "\(lastChargeLevel)%"
    }

    var lastChargedDateText: String {
        let calendar = Calendar.autoupdatingCurrent

        if calendar.isDateInToday(lastChargedAt) {
            return "今天"
        }

        if calendar.isDateInYesterday(lastChargedAt) {
            return "昨天"
        }

        if calendar.isDateInTomorrow(lastChargedAt) {
            return "明天"
        }

        return Self.chineseDateFormatter.string(from: lastChargedAt)
    }

    private static let chineseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = .autoupdatingCurrent
        formatter.dateFormat = "y年M月d日"
        return formatter
    }()

    static let previewDevices: [Device] = [
        Device(
            name: "备用 iPhone",
            category: .phone,
            lastChargedAt: Calendar.current.date(byAdding: .day, value: -18, to: .now) ?? .now,
            lastChargeLevel: 92,
            remindAfterDays: 15,
            notes: "抽屉里备用机"
        ),
        Device(
            name: "Sony 相机",
            category: .camera,
            lastChargedAt: Calendar.current.date(byAdding: .day, value: -27, to: .now) ?? .now,
            lastChargeLevel: 100,
            remindAfterDays: 30,
            notes: "旅行前记得补电"
        ),
        Device(
            name: "Xbox 手柄",
            category: .controller,
            lastChargedAt: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
            lastChargeLevel: 80,
            remindAfterDays: 14,
            notes: "客厅抽屉"
        ),
    ]
}
