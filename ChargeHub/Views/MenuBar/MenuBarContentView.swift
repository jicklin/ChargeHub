#if os(macOS)
    import SwiftUI

    struct MenuBarContentView: View {
        @ObservedObject var store: DeviceStore

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("呦呦百宝箱")
                            .font(.headline)
                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if store.dueDevices.isEmpty {
                    Label("当前没有到期设备", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    Divider()

                    ForEach(Array(store.dueDevices.prefix(4))) { device in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(device.name, systemImage: device.category.iconName)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(badgeText(for: device))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.red)
                            }

                            HStack(spacing: 8) {
                                Button("今天已充电") {
                                    store.markCharged(
                                        deviceID: device.id, level: device.lastChargeLevel)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button("80%") {
                                    store.markCharged(deviceID: device.id, level: 80)
                                }
                                .controlSize(.small)

                                Button("100%") {
                                    store.markCharged(deviceID: device.id, level: 100)
                                }
                                .controlSize(.small)
                            }
                        }

                        if device.id != store.dueDevices.prefix(4).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: 320)
        }

        private var summaryText: String {
            if store.dueDevices.isEmpty {
                return "全部设备都在提醒周期内"
            }

            return "有 \(store.dueDevices.count) 个设备需要补电"
        }

        private func badgeText(for device: Device) -> String {
            switch device.reminderState() {
            case .overdue(let days):
                return "逾期 \(days) 天"
            case .dueToday:
                return "今天提醒"
            case .upcoming(let daysRemaining):
                return "剩 \(daysRemaining) 天"
            case .normal(let daysRemaining):
                return "剩 \(daysRemaining) 天"
            }
        }
    }

    #Preview {
        MenuBarContentView(store: DeviceStore(previewDevices: Device.previewDevices))
    }
#endif
