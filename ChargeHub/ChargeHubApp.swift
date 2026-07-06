import SwiftUI

@main
struct ChargeHubApp: App {
    @StateObject private var store = DeviceStore()
    @StateObject private var referencePhotoStore = ReferencePhotoStore()
    @StateObject private var lifeReminderStore = LifeReminderStore()
    @StateObject private var tripStore = TripStore()
    @StateObject private var syncManager = InfiniCloudSyncManager()

    @SceneBuilder
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: store,
                referencePhotoStore: referencePhotoStore,
                lifeReminderStore: lifeReminderStore,
                tripStore: tripStore,
                syncManager: syncManager
            )
        }

        #if os(macOS)
            MenuBarExtra(menuBarTitle, systemImage: menuBarSymbolName) {
                MenuBarContentView(store: store)
            }
            .menuBarExtraStyle(.window)
        #endif
    }

    private var menuBarTitle: String {
        store.dueDevices.isEmpty ? "呦呦百宝箱" : "呦呦百宝箱 · \(store.dueDevices.count)"
    }

    private var menuBarSymbolName: String {
        store.dueDevices.isEmpty ? "battery.100percent" : "bolt.badge.clock"
    }
}
