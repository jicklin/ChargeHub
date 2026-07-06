import SwiftUI

struct MoreView: View {
    @ObservedObject var store: DeviceStore
    @ObservedObject var referencePhotoStore: ReferencePhotoStore
    @ObservedObject var lifeReminderStore: LifeReminderStore
    @ObservedObject var tripStore: TripStore
    @ObservedObject var syncManager: InfiniCloudSyncManager

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TripsContentView(store: tripStore)
                } label: {
                    MoreNavigationRow(
                        title: "旅行",
                        subtitle: tripSubtitle,
                        systemImage: "airplane.departure",
                        tint: .orange
                    )
                }

                NavigationLink {
                    SettingsContentView(
                        store: store,
                        referencePhotoStore: referencePhotoStore,
                        lifeReminderStore: lifeReminderStore,
                        tripStore: tripStore,
                        syncManager: syncManager
                    )
                } label: {
                    MoreNavigationRow(
                        title: "设置",
                        subtitle: "通知、同步、备份与恢复",
                        systemImage: "gearshape.fill",
                        tint: .gray
                    )
                }
            } header: {
                Text("功能")
            }

            Section {
                Text("呦呦百宝箱专注于提醒低频设备定期补电，避免长期闲置导致电池亏电。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text("关于")
            } footer: {
                Text("版本 \(appVersion)")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("更多")
        .navigationBarTitleDisplayMode(.large)
    }

    private var tripSubtitle: String {
        if tripStore.trips.isEmpty {
            return "还没有旅行记录"
        }
        return "\(tripStore.trips.count) 次旅行"
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        if let build = info?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return version
    }
}

private struct MoreNavigationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.15))
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        MoreView(
            store: DeviceStore(previewDevices: Device.previewDevices),
            referencePhotoStore: ReferencePhotoStore(previewItems: ReferencePhoto.previewItems),
            lifeReminderStore: LifeReminderStore(previewReminders: LifeReminder.previewItems),
            tripStore: TripStore(previewTrips: Trip.previewItems),
            syncManager: InfiniCloudSyncManager()
        )
    }
}
