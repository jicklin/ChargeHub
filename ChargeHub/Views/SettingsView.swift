import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @ObservedObject var store: DeviceStore

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImportURL: URL?
    @State private var showingImportConfirmation = false
    @State private var resultAlert: ResultAlert?
    @State private var shareItem: DeviceLibraryShareItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("当前状态") {
                        Text(notificationStatusText)
                    }

                    Button("请求通知权限") {
                        Task {
                            await store.requestNotificationPermission()
                        }
                    }

                    Button("刷新提醒计划") {
                        Task {
                            await store.refreshNotificationStatus()
                            await store.refreshNotificationsIfAuthorized()
                        }
                    }
                } header: {
                    Text("提醒权限")
                } footer: {
                    Text("设备达到你设置的提醒天数后，会从到期当天开始安排本地提醒；如果仍未记录充电，会继续补发后续提醒。")
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
                } header: {
                    Text("数据概览")
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
                    Text("ChargeHub 专注于提醒低频设备定期补电，避免长期闲置导致电池亏电。")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
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
            .alert(item: $resultAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("知道了"))
                )
            }
        }
    }

    private var defaultExportFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day())
        return "YoChargeHub-设备库-\(date)"
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
    SettingsView(store: DeviceStore(previewDevices: Device.previewDevices))
}
