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
    var imageData: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        category: ReferencePhotoCategory = .other,
        imageData: Data,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
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
