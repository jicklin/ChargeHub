import SwiftUI
import WidgetKit

struct ChargeHubWidgetEntry: TimelineEntry {
    let date: Date
    let devices: [Device]

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
        .sorted { $0.daysSinceCharge(referenceDate: date) > $1.daysSinceCharge(referenceDate: date) }
    }

    var upcomingDevices: [Device] {
        activeDevices.filter {
            if case .upcoming = $0.reminderState(referenceDate: date) {
                return true
            }
            return false
        }
        .sorted { $0.daysSinceCharge(referenceDate: date) > $1.daysSinceCharge(referenceDate: date) }
    }
}

struct ChargeHubWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargeHubWidgetEntry {
        ChargeHubWidgetEntry(date: .now, devices: Device.previewDevices)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargeHubWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargeHubWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(6 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> ChargeHubWidgetEntry {
        ChargeHubWidgetEntry(date: .now, devices: SharedStorage.loadDevices())
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
            Label("ChargeHub", systemImage: "bolt.badge.clock")
                .font(.headline)

            if let firstDue = entry.dueDevices.first {
                Text("该充电")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(firstDue.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(statusText(for: firstDue))
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("没有到期设备")
                    .font(.title3.weight(.semibold))
                Text(entry.upcomingDevices.isEmpty ? "都在安全周期内" : "最近几天有设备将到期")
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
                Label("待补电设备", systemImage: "battery.25")
                    .font(.headline)
                Text("\(entry.dueDevices.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(entry.dueDevices.isEmpty ? "当前无到期设备" : "优先处理逾期或今天提醒的设备")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array((entry.dueDevices.isEmpty ? entry.upcomingDevices : entry.dueDevices).prefix(3))) { device in
                    Link(destination: ChargeHubDeepLink.deviceURL(id: device.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(statusText(for: device))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if entry.dueDevices.isEmpty && entry.upcomingDevices.isEmpty {
                    Text("添加设备后，这里会显示即将到期和已到期项目。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(.background, for: .widget)
    }

    private var primaryWidgetURL: URL {
        if let device = entry.dueDevices.first ?? entry.upcomingDevices.first {
            return ChargeHubDeepLink.deviceURL(id: device.id)
        }

        return ChargeHubDeepLink.rootURL()
    }

    private func statusText(for device: Device) -> String {
        switch device.reminderState(referenceDate: entry.date) {
        case .overdue(let days):
            return "已逾期 \(days) 天"
        case .dueToday:
            return "今天提醒"
        case .upcoming(let daysRemaining):
            return "还有 \(daysRemaining) 天"
        case .normal(let daysRemaining):
            return "还有 \(daysRemaining) 天"
        }
    }
}

struct ChargeHubWidget: Widget {
    let kind: String = "ChargeHubWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargeHubWidgetProvider()) { entry in
            ChargeHubWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("待补电设备")
        .description("查看哪些低频设备已经到提醒周期。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ChargeHubWidget()
} timeline: {
    ChargeHubWidgetEntry(date: .now, devices: Device.previewDevices)
}
