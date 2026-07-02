import Foundation

enum SharedStorage {
    static let appGroupIdentifier = "group.lin.ChargeHub.shared"
    static let devicesFilename = "devices.json"
    static let referencePhotosFilename = "reference-photos.json"
    static let referenceImagesFolderName = "reference-images"
    static let lifeRemindersFilename = "life-reminders.json"
    static let tripsFilename = "trips.json"

    static func devicesFileURL(fileManager: FileManager = .default) -> URL {
        storageFolderURL(fileManager: fileManager).appendingPathComponent(devicesFilename)
    }

    static func referencePhotosFileURL(fileManager: FileManager = .default) -> URL {
        storageFolderURL(fileManager: fileManager).appendingPathComponent(referencePhotosFilename)
    }

    static func lifeRemindersFileURL(fileManager: FileManager = .default) -> URL {
        storageFolderURL(fileManager: fileManager).appendingPathComponent(lifeRemindersFilename)
    }

    static func tripsFileURL(fileManager: FileManager = .default) -> URL {
        storageFolderURL(fileManager: fileManager).appendingPathComponent(tripsFilename)
    }

    static func referenceImagesFolderURL(fileManager: FileManager = .default) -> URL {
        storageFolderURL(fileManager: fileManager)
            .appendingPathComponent(referenceImagesFolderName, isDirectory: true)
    }

    static func referenceImageFileURL(
        filename: String, fileManager: FileManager = .default
    ) -> URL {
        referenceImagesFolderURL(fileManager: fileManager)
            .appendingPathComponent(filename, isDirectory: false)
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

    static func loadLifeReminders(
        fileManager: FileManager = .default, decoder: JSONDecoder = JSONDecoder()
    ) -> [LifeReminder] {
        load(
            [LifeReminder].self, from: lifeRemindersFileURL(fileManager: fileManager),
            fileManager: fileManager, decoder: decoder) ?? []
    }

    static func saveLifeReminders(
        _ reminders: [LifeReminder], fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        try save(
            reminders, to: lifeRemindersFileURL(fileManager: fileManager), fileManager: fileManager,
            encoder: encoder)
    }

    static func loadTrips(
        fileManager: FileManager = .default, decoder: JSONDecoder = JSONDecoder()
    ) -> [Trip] {
        load(
            [Trip].self, from: tripsFileURL(fileManager: fileManager), fileManager: fileManager,
            decoder: decoder) ?? []
    }

    static func saveTrips(
        _ trips: [Trip], fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        try save(
            trips, to: tripsFileURL(fileManager: fileManager), fileManager: fileManager,
            encoder: encoder)
    }

    static func loadReferencePhotos(
        fileManager: FileManager = .default, decoder: JSONDecoder = JSONDecoder()
    ) -> [ReferencePhoto] {
        let metadataURL = referencePhotosFileURL(fileManager: fileManager)
        let folderURL = metadataURL.deletingLastPathComponent()
        let imagesFolderURL = referenceImagesFolderURL(fileManager: fileManager)

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true)

            guard fileManager.fileExists(atPath: metadataURL.path) else {
                return []
            }

            let data = try Data(contentsOf: metadataURL)
            var items = try decoder.decode([ReferencePhoto].self, from: data)
            var shouldRewriteMetadata =
                String(data: data, encoding: .utf8)?.contains("\"imageData\"") == true

            for index in items.indices {
                let imageURL = referenceImageFileURL(
                    filename: items[index].imageFilename, fileManager: fileManager)

                if fileManager.fileExists(atPath: imageURL.path) {
                    items[index].imageData = try Data(contentsOf: imageURL)
                    continue
                }

                if !items[index].imageData.isEmpty {
                    shouldRewriteMetadata = true
                    try items[index].imageData.write(to: imageURL, options: .atomic)
                }
            }

            if shouldRewriteMetadata {
                try saveReferencePhotos(items, fileManager: fileManager)
            }

            return items
        } catch {
            return []
        }
    }

    static func saveReferencePhotos(
        _ items: [ReferencePhoto], fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        let metadataURL = referencePhotosFileURL(fileManager: fileManager)
        let folderURL = metadataURL.deletingLastPathComponent()
        let imagesFolderURL = referenceImagesFolderURL(fileManager: fileManager)

        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true)

        var activeFilenames = Set<String>()
        for item in items {
            activeFilenames.insert(item.imageFilename)
            guard !item.imageData.isEmpty else { continue }

            let imageURL = referenceImageFileURL(
                filename: item.imageFilename, fileManager: fileManager)
            try item.imageData.write(to: imageURL, options: .atomic)
        }

        let data = try encoder.encode(items)
        try data.write(to: metadataURL, options: .atomic)

        let existingImageURLs = try fileManager.contentsOfDirectory(
            at: imagesFolderURL, includingPropertiesForKeys: nil)
        for imageURL in existingImageURLs
        where !activeFilenames.contains(imageURL.lastPathComponent) {
            try? fileManager.removeItem(at: imageURL)
        }
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
