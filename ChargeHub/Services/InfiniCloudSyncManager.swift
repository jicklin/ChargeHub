import Combine
import Foundation
import Security

@MainActor
final class InfiniCloudSyncManager: ObservableObject {
    enum SyncError: LocalizedError {
        case invalidFolderURL
        case missingCredentials
        case remoteFileNotFound(String)
        case unexpectedResponse(Int, String)
        case invalidHTTPResponse
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidFolderURL:
                return "请填写有效的 InfiniCLOUD WebDAV 文件夹地址。"
            case .missingCredentials:
                return "请填写 InfiniCLOUD WebDAV 用户名和应用密码。"
            case .remoteFileNotFound(let filename):
                return "InfiniCLOUD 上还没有找到 \(filename)，请先上传一次本机数据。"
            case .unexpectedResponse(let statusCode, let message):
                return "InfiniCLOUD 返回异常状态码 \(statusCode)：\(message)"
            case .invalidHTTPResponse:
                return "InfiniCLOUD 返回了无效响应。"
            case .keychain(let status):
                return "钥匙串读写失败（\(status)）。"
            }
        }
    }

    struct RemoteSnapshot {
        var devicesData: Data?
        var lifeRemindersData: Data?
        var tripsData: Data?
        var referencePhotos: [ReferencePhoto]?

        var hasAnyData: Bool {
            devicesData != nil || lifeRemindersData != nil || tripsData != nil
                || referencePhotos != nil
        }
    }

    @Published var folderURLString: String
    @Published var username: String
    @Published var password: String
    @Published private(set) var lastSyncDescription: String
    @Published private(set) var isSyncing = false

    private let defaults: UserDefaults
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private static let folderURLDefaultsKey = "infiniCloud.webDAVFolderURL"
    private static let usernameDefaultsKey = "infiniCloud.username"
    private static let lastSyncDescriptionDefaultsKey = "infiniCloud.lastSyncDescription"
    private static let passwordService = "ChargeHub.InfiniCloud.WebDAV"

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        let savedUsername = defaults.string(forKey: Self.usernameDefaultsKey) ?? ""
        self.defaults = defaults
        self.session = session
        self.folderURLString = defaults.string(forKey: Self.folderURLDefaultsKey) ?? ""
        self.username = savedUsername
        self.password = (try? Self.readPassword(username: savedUsername)) ?? ""
        self.lastSyncDescription =
            defaults.string(forKey: Self.lastSyncDescriptionDefaultsKey) ?? "未同步"
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var isConfigured: Bool {
        normalizedFolderURL != nil
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    func saveConfiguration() throws {
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedFolderURL != nil else {
            throw SyncError.invalidFolderURL
        }
        guard !normalizedUsername.isEmpty, !password.isEmpty else {
            throw SyncError.missingCredentials
        }

        username = normalizedUsername
        defaults.set(
            folderURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: Self.folderURLDefaultsKey)
        defaults.set(normalizedUsername, forKey: Self.usernameDefaultsKey)
        try Self.savePassword(password, username: normalizedUsername)
    }

    func upload(
        devicesData: Data,
        lifeRemindersData: Data,
        tripsData: Data,
        referencePhotos: [ReferencePhoto]
    ) async throws {
        try saveConfiguration()
        isSyncing = true
        defer { isSyncing = false }

        try await ensureRemoteFolderExists()
        try await ensureRemoteImagesFolderExists()
        try await put(
            devicesData, filename: SharedStorage.devicesFilename, contentType: "application/json")
        try await put(
            lifeRemindersData, filename: SharedStorage.lifeRemindersFilename,
            contentType: "application/json")
        try await put(
            tripsData, filename: SharedStorage.tripsFilename, contentType: "application/json")

        let referencePhotosData = try encoder.encode(referencePhotos)
        try await put(
            referencePhotosData, filename: SharedStorage.referencePhotosFilename,
            contentType: "application/json")

        for item in referencePhotos where !item.imageData.isEmpty {
            try await putImage(item.imageData, filename: item.imageFilename)
        }

        markSynced("已上传到 InfiniCLOUD · \(Self.timestampFormatter.string(from: .now))")
    }

    func downloadSnapshot() async throws -> RemoteSnapshot {
        try saveConfiguration()
        isSyncing = true
        defer { isSyncing = false }

        let devicesData = try await getIfExists(filename: SharedStorage.devicesFilename)
        let lifeRemindersData = try await getIfExists(filename: SharedStorage.lifeRemindersFilename)
        let tripsData = try await getIfExists(filename: SharedStorage.tripsFilename)
        let referencePhotosData = try await getIfExists(
            filename: SharedStorage.referencePhotosFilename)
        let referencePhotos = try await loadReferencePhotosWithImages(from: referencePhotosData)

        guard
            devicesData != nil || lifeRemindersData != nil || tripsData != nil
                || referencePhotos != nil
        else {
            throw SyncError.remoteFileNotFound("同步数据")
        }

        markSynced("已从 InfiniCLOUD 下载 · \(Self.timestampFormatter.string(from: .now))")
        return RemoteSnapshot(
            devicesData: devicesData,
            lifeRemindersData: lifeRemindersData,
            tripsData: tripsData,
            referencePhotos: referencePhotos
        )
    }

    private var normalizedFolderURL: URL? {
        let trimmed = folderURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
            components.scheme == "https" || components.scheme == "http",
            components.host?.isEmpty == false
        else {
            return nil
        }

        if components.path.isEmpty {
            components.path = "/"
        }
        if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        return components.url
    }

    private var remoteImagesFolderURL: URL? {
        normalizedFolderURL?.appendingPathComponent(
            SharedStorage.referenceImagesFolderName, isDirectory: true)
    }

    private func remoteFileURL(filename: String) throws -> URL {
        guard let folderURL = normalizedFolderURL else {
            throw SyncError.invalidFolderURL
        }
        return folderURL.appendingPathComponent(filename, isDirectory: false)
    }

    private func remoteImageURL(filename: String) throws -> URL {
        guard let imagesFolderURL = remoteImagesFolderURL else {
            throw SyncError.invalidFolderURL
        }
        return imagesFolderURL.appendingPathComponent(filename, isDirectory: false)
    }

    private func authorizedRequest(url: URL, method: String) throws -> URLRequest {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty
        else {
            throw SyncError.missingCredentials
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        let credential = "\(username):\(password)"
        let encodedCredential = Data(credential.utf8).base64EncodedString()
        request.setValue("Basic \(encodedCredential)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func ensureRemoteFolderExists() async throws {
        guard let folderURL = normalizedFolderURL else {
            throw SyncError.invalidFolderURL
        }
        try await makeCollectionIfNeeded(at: folderURL)
    }

    private func ensureRemoteImagesFolderExists() async throws {
        guard let imagesFolderURL = remoteImagesFolderURL else {
            throw SyncError.invalidFolderURL
        }
        try await makeCollectionIfNeeded(at: imagesFolderURL)
    }

    private func makeCollectionIfNeeded(at url: URL) async throws {
        var request = try authorizedRequest(url: url, method: "MKCOL")
        request.timeoutInterval = 30
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidHTTPResponse
        }

        switch httpResponse.statusCode {
        case 200..<300, 405:
            return
        default:
            throw SyncError.unexpectedResponse(
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
    }

    private func put(_ data: Data, filename: String, contentType: String) async throws {
        let url = try remoteFileURL(filename: filename)
        try await put(data, to: url, contentType: contentType)
    }

    private func putImage(_ data: Data, filename: String) async throws {
        let url = try remoteImageURL(filename: filename)
        try await put(data, to: url, contentType: contentType(forImageFilename: filename))
    }

    private func put(_ data: Data, to url: URL, contentType: String) async throws {
        var request = try authorizedRequest(url: url, method: "PUT")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)
        try validateSuccess(response: response)
    }

    private func getIfExists(filename: String) async throws -> Data? {
        let url = try remoteFileURL(filename: filename)
        return try await getIfExists(url: url)
    }

    private func getImageIfExists(filename: String) async throws -> Data? {
        let url = try remoteImageURL(filename: filename)
        return try await getIfExists(url: url)
    }

    private func getIfExists(url: URL) async throws -> Data? {
        let request = try authorizedRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidHTTPResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SyncError.unexpectedResponse(
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }

        return data
    }

    private func loadReferencePhotosWithImages(from data: Data?) async throws -> [ReferencePhoto]? {
        guard let data else { return nil }

        var referencePhotos = try decoder.decode([ReferencePhoto].self, from: data)
        for index in referencePhotos.indices where referencePhotos[index].imageData.isEmpty {
            if let imageData = try await getImageIfExists(
                filename: referencePhotos[index].imageFilename)
            {
                referencePhotos[index].imageData = imageData
            }
        }
        return referencePhotos
    }

    private func validateSuccess(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SyncError.unexpectedResponse(
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
    }

    private func markSynced(_ description: String) {
        lastSyncDescription = description
        defaults.set(description, forKey: Self.lastSyncDescriptionDefaultsKey)
    }

    private func contentType(forImageFilename filename: String) -> String {
        switch filename.lowercased().split(separator: ".").last {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "heic", "heif":
            return "image/heic"
        default:
            return "application/octet-stream"
        }
    }

    private static func savePassword(_ password: String, username: String) throws {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: passwordService,
            kSecAttrAccount as String: username,
        ]

        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status != errSecItemNotFound {
            throw SyncError.keychain(status)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SyncError.keychain(addStatus)
        }
    }

    private static func readPassword(username: String) throws -> String {
        guard !username.isEmpty else { return "" }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: passwordService,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return ""
        }
        guard status == errSecSuccess else {
            throw SyncError.keychain(status)
        }

        guard let data = item as? Data else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}
