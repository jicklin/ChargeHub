import SwiftUI
import WidgetKit

struct ChargeHubWidgetEntry: TimelineEntry {
    let date: Date
    let devices: [Device]
    let reminders: [LifeReminder]

    var activeDevices: [Device] {
        devices.filter { !$0.isArchived }
    }

    var dueDevices: [Device] {
        activeDevices.filter {
            switch $0.reminderState(referenceDate: date) {
            case .overdue, .dueToday:
                true
            default:
                false
            }
        }
        .sorted {
            $0.daysSinceCharge(referenceDate: date) > $1.daysSinceCharge(referenceDate: date)
        }
    }

    var upcomingDevices: [Device] {
        activeDevices.filter {
            if case .upcoming = $0.reminderState(referenceDate: date) {
                return true
            }
            return false
        }
        .sorted {
            $0.daysSinceCharge(referenceDate: date) > $1.daysSinceCharge(referenceDate: date)
        }
    }

    var activeReminders: [LifeReminder] {
        reminders
            .filter { !$0.isCompleted || $0.repeatsAnnually }
            .sorted {
                $0.nextOccurrence(referenceDate: date) < $1.nextOccurrence(referenceDate: date)
            }
    }

    var dueReminders: [LifeReminder] {
        activeReminders.filter {
            switch $0.reminderState(referenceDate: date) {
            case .overdue, .dueToday:
                true
            default:
                false
            }
        }
    }

    var upcomingReminders: [LifeReminder] {
        activeReminders.filter {
            if case .upcoming = $0.reminderState(referenceDate: date) {
                return true
            }
            return false
        }
    }

    var priorityReminderItems: [WidgetReminderItem] {
        let reminderItems = (dueReminders + upcomingReminders).map(WidgetReminderItem.lifeReminder)
        let deviceItems = (dueDevices + upcomingDevices).map(WidgetReminderItem.device)
        return Array((reminderItems + deviceItems).prefix(4))
    }
}

enum WidgetReminderItem: Identifiable {
    case lifeReminder(LifeReminder)
    case device(Device)

    var id: UUID {
        switch self {
        case .lifeReminder(let reminder): reminder.id
        case .device(let device): device.id
        }
    }
}

struct ChargeHubWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargeHubWidgetEntry {
        ChargeHubWidgetEntry(
            date: .now,
            devices: Device.previewDevices,
            reminders: LifeReminder.previewItems
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargeHubWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(
        in context: Context, completion: @escaping (Timeline<ChargeHubWidgetEntry>) -> Void
    ) {
        let entry = makeEntry()
        let nextUpdate =
            Calendar.current.date(byAdding: .hour, value: 6, to: .now)
            ?? .now.addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> ChargeHubWidgetEntry {
        ChargeHubWidgetEntry(
            date: .now,
            devices: SharedStorage.loadDevices(),
            reminders: SharedStorage.loadLifeReminders()
        )
    }
}

struct ChargeHubWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ChargeHubWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ChargeHub", systemImage: "bell.badge")
                .font(.headline)

            if let firstItem = entry.priorityReminderItems.first {
                Text(kindText(for: firstItem))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(titleText(for: firstItem))
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(statusText(for: firstItem))
                    .font(.caption)
                    .foregroundStyle(color(for: firstItem))
            } else {
                Text("暂无近期提醒")
                    .font(.title3.weight(.semibold))
                Text("设备、事件和生日都在安全范围内")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(primaryWidgetURL)
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("近期提醒", systemImage: "bell.badge")
                    .font(.headline)
                Text("\(entry.priorityReminderItems.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(entry.priorityReminderItems.isEmpty ? "暂无需要关注的提醒" : "包含设备、事件和生日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.priorityReminderItems.prefix(3)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText(for: item))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("\(kindText(for: item)) · \(statusText(for: item))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if entry.priorityReminderItems.isEmpty {
                    Text("添加事件、生日或设备后，这里会显示近期需要处理的项目。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(primaryWidgetURL)
    }

    private var primaryWidgetURL: URL {
        if let device = entry.dueDevices.first ?? entry.upcomingDevices.first {
            return ChargeHubDeepLink.deviceURL(id: device.id)
        }

        return ChargeHubDeepLink.rootURL()
    }

    private func kindText(for item: WidgetReminderItem) -> String {
        switch item {
        case .lifeReminder(let reminder): reminder.kind.title
        case .device: "补电"
        }
    }

    private func titleText(for item: WidgetReminderItem) -> String {
        switch item {
        case .lifeReminder(let reminder):
            reminder.trimmedTitle.isEmpty ? reminder.kind.title : reminder.trimmedTitle
        case .device(let device): device.name
        }
    }

    private func statusText(for item: WidgetReminderItem) -> String {
        switch item {
        case .lifeReminder(let reminder):
            switch reminder.reminderState(referenceDate: entry.date) {
            case .overdue(let days): "已逾期 \(days) 天"
            case .dueToday: "今天"
            case .upcoming(let days): "还有 \(days) 天"
            case .future(let days): "还有 \(days) 天"
            }
        case .device(let device):
            switch device.reminderState(referenceDate: entry.date) {
            case .overdue(let days): "已逾期 \(days) 天"
            case .dueToday: "今天提醒"
            case .upcoming(let daysRemaining): "还有 \(daysRemaining) 天"
            case .normal(let daysRemaining): "还有 \(daysRemaining) 天"
            }
        }
    }

    private func color(for item: WidgetReminderItem) -> Color {
        switch item {
        case .lifeReminder(let reminder):
            switch reminder.reminderState(referenceDate: entry.date) {
            case .overdue, .dueToday: .red
            case .upcoming: .orange
            case .future: .secondary
            }
        case .device(let device):
            switch device.reminderState(referenceDate: entry.date) {
            case .overdue, .dueToday: .red
            case .upcoming: .orange
            case .normal: .secondary
            }
        }
    }
}

struct ChargeHubWidget: Widget {
    let kind: String = "ChargeHubWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargeHubWidgetProvider()) { entry in
            ChargeHubWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ChargeHub 提醒")
        .description("查看近期事件、生日和待补电设备。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ChargeHubWidget()
} timeline: {
    ChargeHubWidgetEntry(
        date: .now,
        devices: Device.previewDevices,
        reminders: LifeReminder.previewItems
    )
}
