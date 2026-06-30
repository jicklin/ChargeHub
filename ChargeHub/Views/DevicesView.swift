import SwiftUI

struct DevicesView: View {
    @ObservedObject var store: DeviceStore
    let onAddTapped: () -> Void
    @Binding var deepLinkedDeviceID: UUID?
    @State private var searchText = ""
    @State private var navigationPath: [UUID] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    if filteredActiveDevices.isEmpty {
                        Text(searchText.isEmpty ? "暂无设备" : "没有匹配的设备")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredActiveDevices) { device in
                            NavigationLink(value: device.id) {
                                DeviceRowView(device: device)
                            }
                            .contextMenu {
                                Button("标记今天已充电") {
                                    store.markCharged(deviceID: device.id, level: device.lastChargeLevel)
                                }
                                Button("记录充到 80%") {
                                    store.markCharged(deviceID: device.id, level: 80)
                                }
                                Button(device.isArchived ? "取消归档" : "归档") {
                                    store.toggleArchive(deviceID: device.id)
                                }
                            }
                        }
                    }
                } header: {
                    Text("正在提醒")
                }

                if !filteredArchivedDevices.isEmpty {
                    Section {
                        ForEach(filteredArchivedDevices) { device in
                            NavigationLink(value: device.id) {
                                DeviceRowView(device: device)
                            }
                        }
                    } header: {
                        Text("已归档")
                    }
                }
            }
            .navigationTitle("设备")
            .navigationDestination(for: UUID.self) { deviceID in
                DeviceDetailView(store: store, deviceID: deviceID)
            }
            .searchable(text: $searchText, prompt: "搜索设备名称")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onAddTapped) {
                        Label("添加设备", systemImage: "plus")
                    }
                }
            }
        }
        .onChange(of: deepLinkedDeviceID) { _, newValue in
            searchText = ""

            guard let deviceID = newValue, store.device(withID: deviceID) != nil else {
                navigationPath = []
                return
            }

            navigationPath = [deviceID]
            deepLinkedDeviceID = nil
        }
    }

    private var filteredActiveDevices: [Device] {
        filter(devices: store.activeDevices)
    }

    private var filteredArchivedDevices: [Device] {
        filter(devices: store.archivedDevices)
    }

    private func filter(devices: [Device]) -> [Device] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return devices
        }

        return devices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.category.title.localizedCaseInsensitiveContains(searchText)
                || $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }
}

#Preview {
    @Previewable @State var deepLinkedDeviceID: UUID?
    DevicesView(
        store: DeviceStore(previewDevices: Device.previewDevices),
        onAddTapped: {},
        deepLinkedDeviceID: $deepLinkedDeviceID
    )
}
