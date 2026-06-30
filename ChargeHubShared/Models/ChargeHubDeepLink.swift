import Foundation

enum ChargeHubDeepLinkDestination: Equatable {
    case home
    case device(UUID)
}

enum ChargeHubDeepLink {
    static let scheme = "chargehub"
    static let deviceHost = "device"
    static let homeHost = "home"

    static func deviceURL(id: UUID) -> URL {
        URL(string: "\(scheme)://\(deviceHost)/\(id.uuidString)")!
    }

    static func rootURL() -> URL {
        URL(string: "\(scheme)://\(homeHost)")!
    }

    static func destination(from url: URL) -> ChargeHubDeepLinkDestination? {
        guard url.scheme?.lowercased() == scheme,
              let host = url.host?.lowercased() else {
            return nil
        }

        switch host {
        case deviceHost:
            let identifier = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let id = UUID(uuidString: identifier) else { return nil }
            return .device(id)
        case homeHost:
            return .home
        default:
            return nil
        }
    }
}
