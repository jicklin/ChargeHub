import Foundation
import UserNotifications

struct NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "chargehub.device"
    private let calendar = Calendar.current

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func refreshNotifications(for devices: [Device]) async {
        let identifiers = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(identifierPrefix) }
            .map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for device in devices where !device.isArchived {
            for request in requests(for: device) {
                try? await center.add(request)
            }
        }
    }

    private func requests(for device: Device) -> [UNNotificationRequest] {
        let dueDate = reminderDate(for: device)
        let nextReminderStart = max(dueDate, nextReminderAnchor(after: .now))

        var reminderDates: [Date] = []
        if dueDate > .now.addingTimeInterval(60) {
            reminderDates.append(dueDate)
        }

        for offset in 0..<4 {
            if let followUpDate = calendar.date(byAdding: .day, value: offset, to: nextReminderStart),
               followUpDate > .now.addingTimeInterval(60),
               !reminderDates.contains(where: { calendar.isDate($0, inSameDayAs: followUpDate) }) {
                reminderDates.append(followUpDate)
            }
        }

        return reminderDates.enumerated().map { index, date in
            let content = UNMutableNotificationContent()
            content.title = "该给 \(device.name) 充电了"
            content.body = "它已达到你设置的 \(device.remindAfterDays) 天提醒周期。打开 ChargeHub 记录一下最新状态。"
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(identifierPrefix).\(device.id.uuidString).\(index)"
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    private func reminderDate(for device: Device) -> Date {
        let chargeDay = calendar.startOfDay(for: device.lastChargedAt)
        let dueDay = calendar.date(byAdding: .day, value: device.remindAfterDays, to: chargeDay) ?? chargeDay
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dueDay) ?? dueDay
    }

    private func nextReminderAnchor(after date: Date) -> Date {
        let startOfTomorrow = calendar.startOfDay(for: date.addingTimeInterval(24 * 60 * 60))
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfTomorrow) ?? startOfTomorrow
    }
}
