import Foundation

enum SharedStorage {
    static let appGroupIdentifier = "group.lin.ChargeHub.shared"

    static func devicesFileURL(fileManager: FileManager = .default) -> URL {
        storageFolderURL(fileManager: fileManager).appendingPathComponent("devices.json")
    }

    static func referencePhotosFileURL(fileManager: FileManager = .default) -> URL {
        storageFolderURL(fileManager: fileManager).appendingPathComponent("reference-photos.json")
    }

    static func loadDevices(
        fileManager: FileManager = .default, decoder: JSONDecoder = JSONDecoder()
    ) -> [Device] {
        load(
            [Device].self, from: devicesFileURL(fileManager: fileManager), fileManager: fileManager,
            decoder: decoder) ?? []
    }

    static func saveDevices(
        _ devices: [Device], fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        try save(
            devices, to: devicesFileURL(fileManager: fileManager), fileManager: fileManager,
            encoder: encoder)
    }

    static func loadReferencePhotos(
        fileManager: FileManager = .default, decoder: JSONDecoder = JSONDecoder()
    ) -> [ReferencePhoto] {
        load(
            [ReferencePhoto].self, from: referencePhotosFileURL(fileManager: fileManager),
            fileManager: fileManager, decoder: decoder) ?? []
    }

    static func saveReferencePhotos(
        _ items: [ReferencePhoto], fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        try save(
            items, to: referencePhotosFileURL(fileManager: fileManager), fileManager: fileManager,
            encoder: encoder)
    }

    private static func storageFolderURL(fileManager: FileManager) -> URL {
        if let groupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        {
            return groupURL
        }

        let baseURL =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL.appendingPathComponent("ChargeHub", isDirectory: true)
    }

    private static func load<T: Decodable>(
        _ type: T.Type, from url: URL, fileManager: FileManager, decoder: JSONDecoder
    ) -> T? {
        do {
            let folderURL = url.deletingLastPathComponent()
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }

            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }

    private static func save<T: Encodable>(
        _ value: T, to url: URL, fileManager: FileManager, encoder: JSONEncoder
    ) throws {
        let folderURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
