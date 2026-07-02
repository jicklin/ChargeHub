import Foundation

enum ReferencePhotoCategory: String, CaseIterable, Codable, Identifiable {
    case idDocument
    case qrCode
    case document
    case receipt
    case account
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idDocument:
            return "证件"
        case .qrCode:
            return "二维码"
        case .document:
            return "资料"
        case .receipt:
            return "票据"
        case .account:
            return "账号信息"
        case .other:
            return "其他"
        }
    }

    var iconName: String {
        switch self {
        case .idDocument:
            return "person.text.rectangle"
        case .qrCode:
            return "qrcode"
        case .document:
            return "doc.text.image"
        case .receipt:
            return "receipt"
        case .account:
            return "key"
        case .other:
            return "photo"
        }
    }
}

struct ReferencePhoto: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String
    var category: ReferencePhotoCategory
    var imageFilename: String
    var imageData: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        category: ReferencePhotoCategory = .other,
        imageFilename: String? = nil,
        imageData: Data,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.imageFilename =
            imageFilename ?? Self.defaultImageFilename(for: id, imageData: imageData)
        self.imageData = imageData
        self.createdAt = createdAt
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTitle: String {
        trimmedTitle.isEmpty ? category.title : trimmedTitle
    }

    var isQRCodeReference: Bool {
        category == .qrCode
    }

    var searchableText: String {
        [trimmedTitle, trimmedNotes, category.title]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func defaultImageFilename(for id: UUID, imageData: Data) -> String {
        "\(id.uuidString).\(preferredImageFileExtension(for: imageData))"
    }

    static func preferredImageFileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))

        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if bytes.starts(with: [0x47, 0x49, 0x46]) {
            return "gif"
        }

        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]), bytes.count >= 12,
            bytes[8...11] == [0x57, 0x45, 0x42, 0x50]
        {
            return "webp"
        }

        if bytes.count >= 12,
            bytes[4...7] == [0x66, 0x74, 0x79, 0x70]
        {
            return "heic"
        }

        return "img"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case category
        case imageFilename
        case imageData
        case imageByteCount
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let imageData = try container.decodeIfPresent(Data.self, forKey: .imageData) ?? Data()

        self.id = id
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.category =
            try container.decodeIfPresent(ReferencePhotoCategory.self, forKey: .category) ?? .other
        self.imageFilename =
            try container.decodeIfPresent(String.self, forKey: .imageFilename)
            ?? Self.defaultImageFilename(for: id, imageData: imageData)
        self.imageData = imageData
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(category, forKey: .category)
        try container.encode(imageFilename, forKey: .imageFilename)
        try container.encode(imageData.count, forKey: .imageByteCount)
        try container.encode(createdAt, forKey: .createdAt)
    }

    static let previewItems: [ReferencePhoto] = [
        ReferencePhoto(
            title: "身份证正面",
            notes: "备用登记使用",
            category: .idDocument,
            imageData: Data()
        ),
        ReferencePhoto(
            title: "小区充电桩二维码",
            notes: "B2 停车位右侧，微信扫码可直接充电",
            category: .qrCode,
            imageData: Data()
        ),
    ]
}
