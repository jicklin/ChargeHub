import SwiftUI

@main
struct ChargeHubApp: App {
    @StateObject private var store = DeviceStore()

    @SceneBuilder
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }

#if os(macOS)
        MenuBarExtra(menuBarTitle, systemImage: menuBarSymbolName) {
            MenuBarContentView(store: store)
        }
        .menuBarExtraStyle(.window)
#endif
    }

    private var menuBarTitle: String {
        store.dueDevices.isEmpty ? "ChargeHub" : "ChargeHub · \(store.dueDevices.count)"
    }

    private var menuBarSymbolName: String {
        store.dueDevices.isEmpty ? "battery.100percent" : "bolt.badge.clock"
    }
}
