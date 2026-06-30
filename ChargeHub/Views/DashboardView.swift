import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: DeviceStore
    let onAddTapped: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.activeDevices.isEmpty {
                    ContentUnavailableView(
                        "还没有设备",
                        systemImage: "battery.100percent",
                        description: Text("添加需要低频补电的设备，并设置多少天没充电时提醒。")
                    )
                } else {
                    List {
                        if !store.dueDevices.isEmpty {
                            Section {
                                ForEach(store.dueDevices) { device in
                                    NavigationLink {
                                        DeviceDetailView(store: store, deviceID: device.id)
                                    } label: {
                                        DeviceRowView(device: device)
                                    }
                                }
                            } header: {
                                Text("需要尽快充电")
                            } footer: {
                                Text("达到提醒天数的设备会在通知授权开启后收到本地提醒。")
                            }
                        }

                        if !store.upcomingDevices.isEmpty {
                            Section {
                                ForEach(store.upcomingDevices) { device in
                                    NavigationLink {
                                        DeviceDetailView(store: store, deviceID: device.id)
                                    } label: {
                                        DeviceRowView(device: device)
                                    }
                                }
                            } header: {
                                Text("即将到期")
                            }
                        }

                        let recentlyCharged = Array(store.healthyDevices.sorted { $0.lastChargedAt > $1.lastChargedAt }.prefix(5))
                        if !recentlyCharged.isEmpty {
                            Section {
                                ForEach(recentlyCharged) { device in
                                    NavigationLink {
                                        DeviceDetailView(store: store, deviceID: device.id)
                                    } label: {
                                        DeviceRowView(device: device)
                                    }
                                }
                            } header: {
                                Text("最近更新")
                            }
                        }
                    }
                }
            }
            .navigationTitle("ChargeHub")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onAddTapped) {
                        Label("添加设备", systemImage: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView(store: DeviceStore(previewDevices: Device.previewDevices), onAddTapped: {})
}
