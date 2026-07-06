import Foundation
import UserNotifications

struct NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let deviceIdentifierPrefix = "chargehub.device"
    private let lifeReminderIdentifierPrefix = "chargehub.lifeReminder"
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
            .filter { $0.identifier.hasPrefix(deviceIdentifierPrefix) }
            .map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for device in devices where !device.isArchived {
            for request in requests(for: device) {
                try? await center.add(request)
            }
        }
    }

    func refreshNotifications(for reminders: [LifeReminder]) async {
        let identifiers = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(lifeReminderIdentifierPrefix) }
            .map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for reminder in reminders where !reminder.isCompleted || reminder.repeatsAnnually {
            if let request = request(for: reminder) {
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
            if let followUpDate = calendar.date(
                byAdding: .day, value: offset, to: nextReminderStart),
                followUpDate > .now.addingTimeInterval(60),
                !reminderDates.contains(where: { calendar.isDate($0, inSameDayAs: followUpDate) })
            {
                reminderDates.append(followUpDate)
            }
        }

        return reminderDates.enumerated().map { index, date in
            let content = UNMutableNotificationContent()
            content.title = "该给 \(device.name) 充电了"
            content.body = "它已达到你设置的 \(device.remindAfterDays) 天提醒周期。打开呦呦百宝箱记录一下最新状态。"
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(deviceIdentifierPrefix).\(device.id.uuidString).\(index)"
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
    }

    private func request(for reminder: LifeReminder) -> UNNotificationRequest? {
        guard let notificationDate = notificationDate(for: reminder),
            notificationDate > .now.addingTimeInterval(60)
        else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title =
            reminder.kind == .birthday ? "生日提醒：\(reminder.title)" : "事项提醒：\(reminder.title)"
        content.body = bodyText(for: reminder)
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(lifeReminderIdentifierPrefix).\(reminder.id.uuidString)"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func bodyText(for reminder: LifeReminder) -> String {
        let occurrenceText = reminder.occurrenceDateText()
        if reminder.advanceNoticeDays == 0 {
            return "就是今天：\(occurrenceText)。\(reminder.trimmedNotes)"
        }
        return
            "将在 \(occurrenceText) 到来，已提前 \(reminder.advanceNoticeDays) 天提醒。\(reminder.trimmedNotes)"
    }

    private func notificationDate(for reminder: LifeReminder) -> Date? {
        let occurrence = reminder.nextOccurrence()
        let noticeDay =
            calendar.date(
                byAdding: .day, value: -reminder.advanceNoticeDays,
                to: calendar.startOfDay(for: occurrence)
            ) ?? occurrence
        let noticeDate =
            calendar.date(bySettingHour: 9, minute: 0, second: 0, of: noticeDay) ?? noticeDay

        if noticeDate > .now.addingTimeInterval(60) {
            return noticeDate
        }

        let occurrenceDate =
            calendar.date(bySettingHour: 9, minute: 0, second: 0, of: occurrence) ?? occurrence
        if occurrenceDate > .now.addingTimeInterval(60) {
            return occurrenceDate
        }

        return nil
    }

    private func reminderDate(for device: Device) -> Date {
        let chargeDay = calendar.startOfDay(for: device.lastChargedAt)
        let dueDay =
            calendar.date(byAdding: .day, value: device.remindAfterDays, to: chargeDay) ?? chargeDay
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dueDay) ?? dueDay
    }

    private func nextReminderAnchor(after date: Date) -> Date {
        let startOfTomorrow = calendar.startOfDay(for: date.addingTimeInterval(24 * 60 * 60))
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfTomorrow)
            ?? startOfTomorrow
    }
}
