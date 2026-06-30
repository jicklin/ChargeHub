import Foundation

struct DeviceDraft {
    var name: String = ""
    var category: DeviceCategory = .other
    var lastChargedAt: Date = .now
    var recordChargeLevel: Bool = false
    var lastChargeLevel: Int = 80
    var remindAfterDays: Int = DeviceCategory.other.recommendedReminderDays
    var notes: String = ""
    var isArchived: Bool = false

    init() {}

    init(device: Device) {
        name = device.name
        category = device.category
        lastChargedAt = device.lastChargedAt
        recordChargeLevel = device.lastChargeLevel != nil
        lastChargeLevel = device.lastChargeLevel ?? 80
        remindAfterDays = device.remindAfterDays
        notes = device.notes
        isArchived = device.isArchived
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedChargeLevel: Int? {
        guard recordChargeLevel else { return nil }
        return min(max(lastChargeLevel, 0), 100)
    }

    func makeDevice(existingID: UUID? = nil, createdAt: Date = .now) -> Device {
        Device(
            id: existingID ?? UUID(),
            name: trimmedName,
            category: category,
            lastChargedAt: lastChargedAt,
            lastChargeLevel: normalizedChargeLevel,
            remindAfterDays: remindAfterDays,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isArchived: isArchived,
            createdAt: createdAt
        )
    }
}
