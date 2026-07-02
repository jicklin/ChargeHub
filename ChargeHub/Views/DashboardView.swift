import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: DeviceStore
    @ObservedObject var lifeReminderStore: LifeReminderStore
    @ObservedObject var tripStore: TripStore
    let onAddTapped: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if !lifeReminderStore.visibleHomeReminders.isEmpty {
                    Section {
                        ForEach(lifeReminderStore.visibleHomeReminders) { reminder in
                            LifeReminderRowView(reminder: reminder)
                        }
                    } header: {
                        Text("近期提醒")
                    } footer: {
                        Text("事件和生日会按提醒提前天数出现在这里，并同步显示到小组件。")
                    }
                }

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
                        Text("即将到期设备")
                    }
                }

                if !tripStore.trips.isEmpty {
                    Section {
                        LabeledContent(
                            "旅行总花销", value: dashboardCurrencyText(tripStore.totalExpense))
                        if let latestTrip = tripStore.sortedTrips.first {
                            LabeledContent("最近旅行") {
                                Text(
                                    latestTrip.trimmedTitle.isEmpty
                                        ? "未命名旅行" : latestTrip.trimmedTitle)
                            }
                        }
                    } header: {
                        Text("旅行花销")
                    }
                }

                let recentlyCharged = Array(
                    store.healthyDevices.sorted { $0.lastChargedAt > $1.lastChargedAt }.prefix(5))
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
                        Text("最近更新设备")
                    }
                }

                if store.activeDevices.isEmpty && lifeReminderStore.activeReminders.isEmpty
                    && tripStore.trips.isEmpty
                {
                    Section {
                        ContentUnavailableView(
                            "还没有内容",
                            systemImage: "sparkles",
                            description: Text("添加设备、事件/生日提醒或旅行花销，首页会汇总展示需要关注的内容。")
                        )
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

private func dashboardCurrencyText(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    return formatter.string(from: amount as NSDecimalNumber) ?? "¥0.00"
}

#Preview {
    DashboardView(
        store: DeviceStore(previewDevices: Device.previewDevices),
        lifeReminderStore: LifeReminderStore(previewReminders: LifeReminder.previewItems),
        tripStore: TripStore(previewTrips: Trip.previewItems),
        onAddTapped: {}
    )
}
