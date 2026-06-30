import Foundation

enum DeviceCategory: String, CaseIterable, Codable, Identifiable {
    case phone
    case tablet
    case laptop
    case earbuds
    case watch
    case powerBank
    case camera
    case controller
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phone: "手机"
        case .tablet: "平板"
        case .laptop: "笔记本"
        case .earbuds: "耳机"
        case .watch: "手表"
        case .powerBank: "充电宝"
        case .camera: "相机"
        case .controller: "游戏手柄"
        case .other: "其他"
        }
    }

    var iconName: String {
        switch self {
        case .phone: "iphone"
        case .tablet: "ipad"
        case .laptop: "laptopcomputer"
        case .earbuds: "earbuds"
        case .watch: "applewatch"
        case .powerBank: "battery.100percent"
        case .camera: "camera"
        case .controller: "gamecontroller"
        case .other: "powerplug"
        }
    }

    var recommendedReminderDays: Int {
        switch self {
        case .phone: 7
        case .tablet: 10
        case .laptop: 14
        case .earbuds: 10
        case .watch: 7
        case .powerBank: 20
        case .camera: 30
        case .controller: 15
        case .other: 14
        }
    }
}
