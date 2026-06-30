import SwiftUI

struct DeviceDetailView: View {
    @ObservedObject var store: DeviceStore
    let deviceID: UUID

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingChargeDialog = false

    var body: some View {
        Group {
            if let device {
                Form {
                    Section {
                        LabeledContent("设备") {
                            Label(device.category.title, systemImage: device.category.iconName)
                        }
                        LabeledContent("上次充电") {
                            Text(device.lastChargedDateText)
                        }
                        LabeledContent("上次充到") {
                            Text(device.chargeLevelText)
                        }
                        LabeledContent("提醒规则") {
                            Text("超过 \(device.remindAfterDays) 天提醒")
                        }
                        LabeledContent("当前状态") {
                            Text(statusDescription(for: device))
                                .foregroundStyle(statusColor(for: device))
                        }
                    } header: {
                        Text("当前状态")
                    }

                    Section {
                        Button {
                            store.markCharged(deviceID: device.id, level: nil)
                        } label: {
                            Label("仅记录今天已充电", systemImage: "checkmark.circle")
                        }

                        Button {
                            store.markCharged(deviceID: device.id, level: 80)
                        } label: {
                            Label("记录今天充到 80%", systemImage: "battery.75")
                        }

                        Button {
                            store.markCharged(deviceID: device.id, level: 100)
                        } label: {
                            Label("记录今天充到 100%", systemImage: "battery.100percent")
                        }

                        Button {
                            showingChargeDialog = true
                        } label: {
                            Label("更多登记方式", systemImage: "ellipsis.circle")
                        }
                    } header: {
                        Text("快速操作")
                    }

                    if !device.notes.isEmpty {
                        Section {
                            Text(device.notes)
                        } header: {
                            Text("备注")
                        }
                    }

                    Section {
                        Button("编辑设备") {
                            showingEditSheet = true
                        }

                        Button(device.isArchived ? "取消归档" : "归档设备") {
                            store.toggleArchive(deviceID: device.id)
                        }

                        Button("删除设备", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } header: {
                        Text("管理")
                    }
                }
                .navigationTitle(device.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("编辑") {
                            showingEditSheet = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditSheet) {
                    NavigationStack {
                        DeviceFormView(store: store, existingDevice: device)
                    }
                }
                .confirmationDialog("记录本次充电", isPresented: $showingChargeDialog) {
                    Button("记录今天充到 60%") {
                        store.markCharged(deviceID: device.id, level: 60)
                    }
                    Button("记录今天充到 90%") {
                        store.markCharged(deviceID: device.id, level: 90)
                    }
                    Button("保留原百分比，仅更新时间") {
                        store.markCharged(deviceID: device.id, level: device.lastChargeLevel)
                    }
                }
                .alert("删除设备？", isPresented: $showingDeleteAlert) {
                    Button("删除", role: .destructive) {
                        store.deleteDevice(deviceID: device.id)
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("删除后无法恢复。")
                }
            } else {
                ContentUnavailableView(
                    "设备不存在",
                    systemImage: "tray",
                    description: Text("它可能已经被删除。")
                )
            }
        }
    }

    private var device: Device? {
        store.device(withID: deviceID)
    }

    private func statusDescription(for device: Device) -> String {
        switch device.reminderState() {
        case .overdue(let days):
            return "已超过提醒时间 \(days) 天"
        case .dueToday:
            return "今天需要补电"
        case .upcoming(let daysRemaining):
            return "还有 \(daysRemaining) 天会提醒"
        case .normal(let daysRemaining):
            return "距离提醒还有 \(daysRemaining) 天"
        }
    }

    private func statusColor(for device: Device) -> Color {
        switch device.reminderState() {
        case .overdue:
            return .red
        case .dueToday:
            return .orange
        case .upcoming:
            return .yellow
        case .normal:
            return .green
        }
    }
}

#Preview {
    NavigationStack {
        DeviceDetailView(store: DeviceStore(previewDevices: Device.previewDevices), deviceID: Device.previewDevices[0].id)
    }
}
