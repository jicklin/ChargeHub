import SwiftUI

private enum RootTab: Hashable {
    case dashboard
    case devices
    case references
    case settings
}

struct ContentView: View {
    @ObservedObject var store: DeviceStore
    @ObservedObject var referencePhotoStore: ReferencePhotoStore
    @State private var showingAddDevice = false
    @State private var selectedTab: RootTab = .dashboard
    @State private var deepLinkedDeviceID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(store: store, onAddTapped: { showingAddDevice = true })
                .tabItem {
                    Label("首页", systemImage: "bolt.badge.clock")
                }
                .tag(RootTab.dashboard)

            DevicesView(
                store: store,
                onAddTapped: { showingAddDevice = true },
                deepLinkedDeviceID: $deepLinkedDeviceID
            )
            .tabItem {
                Label("设备", systemImage: "list.bullet.rectangle")
            }
            .tag(RootTab.devices)

            ReferencePhotosView(store: referencePhotoStore)
                .tabItem {
                    Label("资料", systemImage: "photo.stack")
                }
                .tag(RootTab.references)

            SettingsView(store: store)
                .tabItem {
                    Label("设置", systemImage: "bell.badge")
                }
                .tag(RootTab.settings)
        }
        .sheet(isPresented: $showingAddDevice) {
            NavigationStack {
                DeviceFormView(store: store)
            }
        }
        .onOpenURL { url in
            guard let destination = ChargeHubDeepLink.destination(from: url) else {
                return
            }

            showingAddDevice = false
            selectedTab = .devices

            switch destination {
            case .home:
                deepLinkedDeviceID = nil
            case .device(let deviceID):
                deepLinkedDeviceID = store.device(withID: deviceID) != nil ? deviceID : nil
            }
        }
    }
}

#Preview {
    ContentView(
        store: DeviceStore(previewDevices: Device.previewDevices),
        referencePhotoStore: ReferencePhotoStore(previewItems: ReferencePhoto.previewItems)
    )
}
