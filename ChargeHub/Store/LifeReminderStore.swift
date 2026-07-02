import Combine
import Foundation
import UserNotifications

#if canImport(WidgetKit)
    import WidgetKit
#endif

@MainActor
final class LifeReminderStore: ObservableObject {
    @Published private(set) var reminders: [LifeReminder]

    struct ImportSummary {
        let total: Int
        let added: Int
        let updated: Int
        let replacedAll: Bool
    }

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let notificationManager = NotificationManager()
    private let usesInMemoryStore: Bool

    init(previewReminders: [LifeReminder]? = nil) {
        if let previewReminders {
            self.reminders = previewReminders
            self.usesInMemoryStore = true
        } else {
            self.reminders = SharedStorage.loadLifeReminders(fileManager: fileManager)
            self.usesInMemoryStore = false
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        Task {
            await refreshNotificationsIfAuthorized()
        }
    }

    var activeReminders: [LifeReminder] {
        reminders
            .filter { !$0.isCompleted || $0.repeatsAnnually }
            .sorted { lhs, rhs in
                lhs.nextOccurrence() < rhs.nextOccurrence()
            }
    }

    var dueReminders: [LifeReminder] {
        activeReminders.filter {
            switch $0.reminderState() {
            case .overdue, .dueToday:
                true
            default:
                false
            }
        }
    }

    var upcomingReminders: [LifeReminder] {
        activeReminders.filter {
            if case .upcoming = $0.reminderState() {
                return true
            }
            return false
        }
    }

    var visibleHomeReminders: [LifeReminder] {
        Array((dueReminders + upcomingReminders).prefix(5))
    }

    func reminder(withID id: UUID) -> LifeReminder? {
        reminders.first { $0.id == id }
    }

    func addReminder(_ reminder: LifeReminder) {
        reminders.append(reminder)
        save()
    }

    func updateReminder(_ reminder: LifeReminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        save()
    }

    func toggleCompleted(id: UUID) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].isCompleted.toggle()
        save()
    }

    func deleteReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    func exportData() throws -> Data {
        try encoder.encode(reminders)
    }

    func replaceRemindersFromSync(from data: Data) throws -> ImportSummary {
        let imported = try decodeReminders(from: data)
        reminders = imported
        save()
        return ImportSummary(
            total: imported.count, added: imported.count, updated: 0, replacedAll: true)
    }

    func mergeRemindersFromSync(from data: Data) throws -> ImportSummary {
        let imported = try decodeReminders(from: data)
        var merged = reminders
        var indexByID = Dictionary(
            uniqueKeysWithValues: merged.enumerated().map { ($0.element.id, $0.offset) })
        var added = 0
        var updated = 0

        for reminder in imported {
            if let index = indexByID[reminder.id] {
                merged[index] = reminder
                updated += 1
            } else {
                indexByID[reminder.id] = merged.count
                merged.append(reminder)
                added += 1
            }
        }

        reminders = merged
        save()
        return ImportSummary(
            total: imported.count, added: added, updated: updated, replacedAll: false)
    }

    private func decodeReminders(from data: Data) throws -> [LifeReminder] {
        try JSONDecoder().decode([LifeReminder].self, from: data)
    }

    func refreshNotificationsIfAuthorized() async {
        let status = await notificationManager.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            await notificationManager.refreshNotifications(for: activeReminders)
        default:
            break
        }
    }

    private func save() {
        guard !usesInMemoryStore else { return }

        do {
            try SharedStorage.saveLifeReminders(
                reminders, fileManager: fileManager, encoder: encoder)
            Task {
                await refreshNotificationsIfAuthorized()
            }
            #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            assertionFailure("Failed to save life reminders: \(error.localizedDescription)")
        }
    }
}
