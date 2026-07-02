import Combine
import Foundation
import UserNotifications

#if canImport(WidgetKit)
    import WidgetKit
#endif

@MainActor
final class DeviceStore: ObservableObject {
    @Published private(set) var devices: [Device]
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    struct ImportSummary {
        let total: Int
        let added: Int
        let updated: Int
        let replacedAll: Bool
    }

    enum ImportError: LocalizedError {
        case emptyData

        var errorDescription: String? {
            switch self {
            case .emptyData:
                return "导入文件中没有可用的设备数据。"
            }
        }
    }

    private let notificationManager = NotificationManager()
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let usesInMemoryStore: Bool

    init(previewDevices: [Device]? = nil) {
        if let previewDevices {
            self.devices = previewDevices
            self.usesInMemoryStore = true
        } else {
            self.usesInMemoryStore = false
            self.devices = SharedStorage.loadDevices(fileManager: fileManager)
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        Task {
            await refreshNotificationStatus()
            await refreshNotificationsIfAuthorized()
        }
    }

    var activeDevices: [Device] {
        devices
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                lhs.daysSinceCharge() > rhs.daysSinceCharge()
            }
    }

    var archivedDevices: [Device] {
        devices
            .filter(\.isArchived)
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var dueDevices: [Device] {
        activeDevices.filter {
            switch $0.reminderState() {
            case .overdue, .dueToday:
                true
            default:
                false
            }
        }
    }

    var upcomingDevices: [Device] {
        activeDevices.filter {
            if case .upcoming = $0.reminderState() {
                return true
            }
            return false
        }
    }

    var healthyDevices: [Device] {
        activeDevices.filter {
            if case .normal = $0.reminderState() {
                return true
            }
            return false
        }
    }

    func device(withID id: UUID) -> Device? {
        devices.first(where: { $0.id == id })
    }

    func addDevice(from draft: DeviceDraft) {
        let device = draft.makeDevice()
        devices.append(device)
        persistAndRefreshNotifications()
    }

    func updateDevice(id: UUID, with draft: DeviceDraft) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        let createdAt = devices[index].createdAt
        devices[index] = draft.makeDevice(existingID: id, createdAt: createdAt)
        persistAndRefreshNotifications()
    }

    func markCharged(deviceID: UUID, level: Int?) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].lastChargedAt = .now
        devices[index].lastChargeLevel = level
        persistAndRefreshNotifications()
    }

    func toggleArchive(deviceID: UUID) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].isArchived.toggle()
        persistAndRefreshNotifications()
    }

    func deleteDevice(deviceID: UUID) {
        devices.removeAll { $0.id == deviceID }
        persistAndRefreshNotifications()
    }

    func requestNotificationPermission() async {
        _ = await notificationManager.requestAuthorization()
        await refreshNotificationStatus()
        await refreshNotificationsIfAuthorized()
    }

    func exportDocument() -> DeviceLibraryDocument {
        DeviceLibraryDocument(devices: devices)
    }

    func exportData() throws -> Data {
        try encoder.encode(devices)
    }

    func exportShareItem(filename: String) throws -> DeviceLibraryShareItem {
        DeviceLibraryShareItem(data: try exportData(), filename: filename)
    }

    func importDevices(from url: URL) throws -> ImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        return try replaceDevices(from: data)
    }

    func replaceDevices(from data: Data) throws -> ImportSummary {
        let importedDevices = try decodeImportedDevices(from: data)
        devices = importedDevices
        persistAndRefreshNotifications()
        return ImportSummary(
            total: importedDevices.count, added: importedDevices.count, updated: 0,
            replacedAll: true)
    }

    func mergeDevices(from url: URL) throws -> ImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        return try mergeDevices(from: data)
    }

    func mergeDevices(from data: Data) throws -> ImportSummary {
        try mergeDevices(from: data, allowEmpty: false)
    }

    func replaceDevicesFromSync(from data: Data) throws -> ImportSummary {
        let importedDevices = try decodeImportedDevices(from: data, allowEmpty: true)
        devices = importedDevices
        persistAndRefreshNotifications()
        return ImportSummary(
            total: importedDevices.count, added: importedDevices.count, updated: 0,
            replacedAll: true)
    }

    func mergeDevicesFromSync(from data: Data) throws -> ImportSummary {
        try mergeDevices(from: data, allowEmpty: true)
    }

    private func mergeDevices(from data: Data, allowEmpty: Bool) throws -> ImportSummary {
        let importedDevices = try decodeImportedDevices(from: data, allowEmpty: allowEmpty)

        var mergedDevices = devices
        var indexByID = Dictionary(
            uniqueKeysWithValues: mergedDevices.enumerated().map { ($0.element.id, $0.offset) })
        var added = 0
        var updated = 0

        for importedDevice in importedDevices {
            if let index = indexByID[importedDevice.id] {
                mergedDevices[index] = importedDevice
                updated += 1
            } else {
                indexByID[importedDevice.id] = mergedDevices.count
                mergedDevices.append(importedDevice)
                added += 1
            }
        }

        devices = mergedDevices
        persistAndRefreshNotifications()
        return ImportSummary(
            total: importedDevices.count, added: added, updated: updated, replacedAll: false)
    }

    func refreshNotificationStatus() async {
        notificationStatus = await notificationManager.authorizationStatus()
    }

    func refreshNotificationsIfAuthorized() async {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            await notificationManager.refreshNotifications(for: activeDevices)
        default:
            break
        }
    }

    private func decodeImportedDevices(from data: Data, allowEmpty: Bool = false) throws -> [Device]
    {
        let decoder = JSONDecoder()
        let importedDevices = try decoder.decode([Device].self, from: data)

        guard allowEmpty || !importedDevices.isEmpty else {
            throw ImportError.emptyData
        }

        return importedDevices
    }

    private func persistAndRefreshNotifications() {
        save()
        Task {
            await refreshNotificationStatus()
            await refreshNotificationsIfAuthorized()
        }
    }

    private func save() {
        guard !usesInMemoryStore else { return }

        do {
            try SharedStorage.saveDevices(devices, fileManager: fileManager, encoder: encoder)
            #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            assertionFailure("Failed to save devices: \(error.localizedDescription)")
        }
    }
}
