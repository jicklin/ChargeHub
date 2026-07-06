import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsContentView: View {
    @ObservedObject var store: DeviceStore
    @ObservedObject var referencePhotoStore: ReferencePhotoStore
    @ObservedObject var lifeReminderStore: LifeReminderStore
    @ObservedObject var tripStore: TripStore
    @ObservedObject var syncManager: InfiniCloudSyncManager

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImportURL: URL?
    @State private var showingImportConfirmation = false
    @State private var pendingCloudDownloadMode: ImportMode?
    @State private var resultAlert: ResultAlert?
    @State private var shareItem: DeviceLibraryShareItem?

    var body: some View {
        Form {
            Section {
                LabeledContent("当前状态") {
                    Text(notificationStatusText)
                }

                Button("请求通知权限") {
                    Task {
                        await store.requestNotificationPermission()
                        await lifeReminderStore.refreshNotificationsIfAuthorized()
                    }
                }

                Button("刷新提醒计划") {
                    Task {
                        await store.refreshNotificationStatus()
                        await store.refreshNotificationsIfAuthorized()
                        await lifeReminderStore.refreshNotificationsIfAuthorized()
                    }
                }
            } header: {
                Text("提醒权限")
            } footer: {
                Text("设备、事件和生日会根据各自的提醒规则安排本地通知；首页和小组件也会展示近期需要关注的提醒。")
            }

            Section {
                LabeledContent("活跃设备") {
                    Text("\(store.activeDevices.count)")
                }
                LabeledContent("待充电") {
                    Text("\(store.dueDevices.count)")
                }
                LabeledContent("已归档") {
                    Text("\(store.archivedDevices.count)")
                }
                LabeledContent("资料图片") {
                    Text("\(referencePhotoStore.items.count)")
                }
                LabeledContent("提醒事项") {
                    Text("\(lifeReminderStore.reminders.count)")
                }
                LabeledContent("旅行记录") {
                    Text("\(tripStore.trips.count)")
                }
            } header: {
                Text("数据概览")
            }

            Section {
                TextField("WebDAV 文件夹地址", text: $syncManager.folderURLString)
                    .autocorrectionDisabled()
                TextField("用户名", text: $syncManager.username)
                    .autocorrectionDisabled()
                SecureField("应用密码 / WebDAV 密码", text: $syncManager.password)

                LabeledContent("同步状态") {
                    Text(syncManager.lastSyncDescription)
                }

                Button {
                    saveInfiniCloudConfiguration()
                } label: {
                    Label("保存同步设置", systemImage: "checkmark.circle")
                }

                Button {
                    Task { await uploadToInfiniCloud() }
                } label: {
                    Label("上传当前数据到 InfiniCLOUD", systemImage: "icloud.and.arrow.up")
                }
                .disabled(syncManager.isSyncing)

                Button {
                    pendingCloudDownloadMode = .merge
                } label: {
                    Label("从 InfiniCLOUD 合并下载", systemImage: "icloud.and.arrow.down")
                }
                .disabled(syncManager.isSyncing)

                Button(role: .destructive) {
                    pendingCloudDownloadMode = .replace
                } label: {
                    Label("从 InfiniCLOUD 覆盖本机", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(syncManager.isSyncing)
            } header: {
                Text("InfiniCLOUD 同步")
            } footer: {
                Text(
                    "使用 InfiniCLOUD 的 WebDAV 作为同步载体，会在远端保存 devices.json、life-reminders.json、trips.json、reference-photos.json 和 reference-images/ 图片文件夹。建议地址使用专门目录，例如 https://你的账号.infini-cloud.net/dav/YoYoToolbox/；密码请使用 InfiniCLOUD 提供的应用密码或 WebDAV 密码。"
                )
            }

            Section {
                if let shareItem {
                    ShareLink(item: shareItem, preview: SharePreview(defaultExportFilename)) {
                        Label("快速分享设备库", systemImage: "square.and.arrow.up.on.square")
                    }
                } else {
                    Button {
                        prepareShareItem()
                    } label: {
                        Label("快速分享设备库", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                Button {
                    showingExporter = true
                } label: {
                    Label("导出设备库 JSON", systemImage: "square.and.arrow.up")
                }

                Button {
                    showingImporter = true
                } label: {
                    Label("导入设备库 JSON", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("备份与恢复")
            } footer: {
                Text("导入会替换当前设备库。建议先导出备份，再执行导入。快速分享适合直接通过 AirDrop、聊天工具或文件发送给家里人。")
            }

            Section {
                Text("呦呦百宝箱专注于提醒低频设备定期补电，避免长期闲置导致电池亏电。")
                    .foregroundStyle(.secondary)
            } header: {
                Text("关于")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshNotificationStatus()
            prepareShareItem()
        }
        .onChange(of: store.devices) { _, _ in
            prepareShareItem()
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: store.exportDocument(),
            contentType: .json,
            defaultFilename: defaultExportFilename
        ) { result in
            switch result {
            case .success:
                resultAlert = ResultAlert(title: "导出成功", message: "设备库已经导出为 JSON 文件。")
            case .failure(let error):
                resultAlert = ResultAlert(title: "导出失败", message: error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                pendingImportURL = urls.first
                showingImportConfirmation = pendingImportURL != nil
            case .failure(let error):
                resultAlert = ResultAlert(title: "导入失败", message: error.localizedDescription)
            }
        }
        .confirmationDialog(
            "导入设备库", isPresented: $showingImportConfirmation, titleVisibility: .visible
        ) {
            Button("合并导入") {
                performImport(mode: .merge)
            }
            Button("替换当前数据", role: .destructive) {
                performImport(mode: .replace)
            }
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("你可以选择合并导入或替换当前设备库。合并模式会按设备 ID 合并：同 ID 覆盖，本地没有的设备会追加。")
        }
        .confirmationDialog(
            "从 InfiniCLOUD 下载", isPresented: cloudDownloadConfirmationBinding,
            titleVisibility: .visible
        ) {
            if pendingCloudDownloadMode == .merge {
                Button("合并下载") {
                    Task { await downloadFromInfiniCloud(mode: .merge) }
                }
            }
            if pendingCloudDownloadMode == .replace {
                Button("覆盖本机数据", role: .destructive) {
                    Task { await downloadFromInfiniCloud(mode: .replace) }
                }
            }
            Button("取消", role: .cancel) {
                pendingCloudDownloadMode = nil
            }
        } message: {
            Text(cloudDownloadConfirmationMessage)
        }
        .alert(item: $resultAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    private var defaultExportFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day())
        return "呦呦百宝箱-设备库-\(date)"
    }

    private var cloudDownloadConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingCloudDownloadMode != nil },
            set: { isPresented in
                if !isPresented {
                    pendingCloudDownloadMode = nil
                }
            }
        )
    }

    private var cloudDownloadConfirmationMessage: String {
        switch pendingCloudDownloadMode {
        case .merge:
            return "会下载 InfiniCLOUD 上的设备库、提醒、旅行和资料库，并按 ID 合并到本机；同 ID 数据以远端为准。"
        case .replace:
            return "会用 InfiniCLOUD 上的设备库、提醒、旅行和资料库覆盖本机当前数据。建议先上传或导出备份。"
        case nil:
            return ""
        }
    }

    private func saveInfiniCloudConfiguration() {
        do {
            try syncManager.saveConfiguration()
            resultAlert = ResultAlert(title: "设置已保存", message: "InfiniCLOUD WebDAV 设置已保存到本机。")
        } catch {
            resultAlert = ResultAlert(title: "设置保存失败", message: error.localizedDescription)
        }
    }

    private func uploadToInfiniCloud() async {
        do {
            let devicesData = try store.exportData()
            let lifeRemindersData = try lifeReminderStore.exportData()
            let tripsData = try tripStore.exportData()
            try await syncManager.upload(
                devicesData: devicesData,
                lifeRemindersData: lifeRemindersData,
                tripsData: tripsData,
                referencePhotos: referencePhotoStore.items)
            resultAlert = ResultAlert(
                title: "上传成功",
                message: "已将设备库、提醒、旅行和资料库上传到 InfiniCLOUD。")
        } catch {
            resultAlert = ResultAlert(title: "上传失败", message: error.localizedDescription)
        }
    }

    private func downloadFromInfiniCloud(mode: ImportMode) async {
        defer { pendingCloudDownloadMode = nil }

        do {
            let snapshot = try await syncManager.downloadSnapshot()
            var messages: [String] = []

            if let devicesData = snapshot.devicesData {
                let summary: DeviceStore.ImportSummary
                switch mode {
                case .replace:
                    summary = try store.replaceDevicesFromSync(from: devicesData)
                case .merge:
                    summary = try store.mergeDevicesFromSync(from: devicesData)
                }
                messages.append(deviceSyncMessage(for: summary))
            } else {
                messages.append("远端没有设备库文件，已跳过设备库。")
            }

            if let lifeRemindersData = snapshot.lifeRemindersData {
                let summary: LifeReminderStore.ImportSummary
                switch mode {
                case .replace:
                    summary = try lifeReminderStore.replaceRemindersFromSync(
                        from: lifeRemindersData)
                case .merge:
                    summary = try lifeReminderStore.mergeRemindersFromSync(from: lifeRemindersData)
                }
                messages.append(lifeReminderSyncMessage(for: summary))
            } else {
                messages.append("远端没有提醒文件，已跳过提醒。")
            }

            if let tripsData = snapshot.tripsData {
                let summary: TripStore.ImportSummary
                switch mode {
                case .replace:
                    summary = try tripStore.replaceTripsFromSync(from: tripsData)
                case .merge:
                    summary = try tripStore.mergeTripsFromSync(from: tripsData)
                }
                messages.append(tripSyncMessage(for: summary))
            } else {
                messages.append("远端没有旅行文件，已跳过旅行。")
            }

            if let referencePhotos = snapshot.referencePhotos {
                let summary: ReferencePhotoStore.ImportSummary
                switch mode {
                case .replace:
                    summary = try referencePhotoStore.replaceItemsFromSync(referencePhotos)
                case .merge:
                    summary = try referencePhotoStore.mergeItemsFromSync(referencePhotos)
                }
                messages.append(referencePhotoSyncMessage(for: summary))
            } else {
                messages.append("远端没有资料库文件，已跳过资料库。")
            }

            prepareShareItem()
            resultAlert = ResultAlert(
                title: mode == .replace ? "覆盖完成" : "合并完成",
                message: messages.joined(separator: "\n")
            )
        } catch {
            resultAlert = ResultAlert(title: "下载失败", message: error.localizedDescription)
        }
    }

    private func performImport(mode: ImportMode) {
        defer { pendingImportURL = nil }

        guard let url = pendingImportURL else { return }

        do {
            let summary: DeviceStore.ImportSummary
            switch mode {
            case .replace:
                summary = try store.importDevices(from: url)
            case .merge:
                summary = try store.mergeDevices(from: url)
            }

            prepareShareItem()
            resultAlert = ResultAlert(
                title: mode == .replace ? "导入成功" : "合并成功",
                message: importMessage(for: summary)
            )
        } catch {
            resultAlert = ResultAlert(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func importMessage(for summary: DeviceStore.ImportSummary) -> String {
        if summary.replacedAll {
            return "设备库已替换完成，共导入 \(summary.total) 条设备数据。"
        }

        return "本次共处理 \(summary.total) 条设备数据，新增 \(summary.added) 条，覆盖更新 \(summary.updated) 条。"
    }

    private func deviceSyncMessage(for summary: DeviceStore.ImportSummary) -> String {
        if summary.replacedAll {
            return "设备库已覆盖为远端数据，共 \(summary.total) 条。"
        }

        return "设备库已合并：处理 \(summary.total) 条，新增 \(summary.added) 条，更新 \(summary.updated) 条。"
    }

    private func lifeReminderSyncMessage(for summary: LifeReminderStore.ImportSummary) -> String {
        if summary.replacedAll {
            return "提醒已覆盖为远端数据，共 \(summary.total) 条。"
        }

        return "提醒已合并：处理 \(summary.total) 条，新增 \(summary.added) 条，更新 \(summary.updated) 条。"
    }

    private func tripSyncMessage(for summary: TripStore.ImportSummary) -> String {
        if summary.replacedAll {
            return "旅行已覆盖为远端数据，共 \(summary.total) 条。"
        }

        return "旅行已合并：处理 \(summary.total) 条，新增 \(summary.added) 条，更新 \(summary.updated) 条。"
    }

    private func referencePhotoSyncMessage(for summary: ReferencePhotoStore.ImportSummary) -> String
    {
        if summary.replacedAll {
            return "资料库已覆盖为远端数据，共 \(summary.total) 条。"
        }

        return "资料库已合并：处理 \(summary.total) 条，新增 \(summary.added) 条，更新 \(summary.updated) 条。"
    }

    private func prepareShareItem() {
        do {
            shareItem = try store.exportShareItem(filename: defaultExportFilename)
        } catch {
            shareItem = nil
        }
    }

    private var notificationStatusText: String {
        switch store.notificationStatus {
        case .notDetermined:
            return "未请求"
        case .denied:
            return "已拒绝"
        case .authorized:
            return "已允许"
        case .provisional:
            return "临时授权"
        case .ephemeral:
            return "临时会话授权"
        @unknown default:
            return "未知"
        }
    }
}

private enum ImportMode {
    case replace
    case merge
}

private struct ResultAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        SettingsContentView(
            store: DeviceStore(previewDevices: Device.previewDevices),
            referencePhotoStore: ReferencePhotoStore(previewItems: ReferencePhoto.previewItems),
            lifeReminderStore: LifeReminderStore(previewReminders: LifeReminder.previewItems),
            tripStore: TripStore(previewTrips: Trip.previewItems),
            syncManager: InfiniCloudSyncManager()
        )
    }
}
