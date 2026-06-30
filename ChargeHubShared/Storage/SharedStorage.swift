import Foundation

enum SharedStorage {
    static let appGroupIdentifier = "group.lin.ChargeHub.shared"

    static func devicesFileURL(fileManager: FileManager = .default) -> URL {
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL.appendingPathComponent("devices.json")
        }

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folderURL = baseURL.appendingPathComponent("ChargeHub", isDirectory: true)
        return folderURL.appendingPathComponent("devices.json")
    }

    static func loadDevices(fileManager: FileManager = .default, decoder: JSONDecoder = JSONDecoder()) -> [Device] {
        let storageURL = devicesFileURL(fileManager: fileManager)

        do {
            let folderURL = storageURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            guard fileManager.fileExists(atPath: storageURL.path) else {
                return []
            }

            let data = try Data(contentsOf: storageURL)
            return try decoder.decode([Device].self, from: data)
        } catch {
            return []
        }
    }

    static func saveDevices(_ devices: [Device], fileManager: FileManager = .default, encoder: JSONEncoder = JSONEncoder()) throws {
        let storageURL = devicesFileURL(fileManager: fileManager)
        let folderURL = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(devices)
        try data.write(to: storageURL, options: .atomic)
    }
}
