import PhotosUI
import SwiftUI

#if os(iOS)
    import Photos
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct ReferencePhotosView: View {
    @ObservedObject var store: ReferencePhotoStore

    @State private var searchText = ""
    @State private var selectedCategory: ReferencePhotoFilter = .all
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var importAlert: ReferencePhotoImportAlert?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterBar

                    if filteredItems.isEmpty {
                        ContentUnavailableView(
                            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "还没有资料图片" : "没有匹配的图片",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text(emptyDescription)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredItems) { item in
                                NavigationLink {
                                    ReferencePhotoDetailView(store: store, itemID: item.id)
                                } label: {
                                    ReferencePhotoCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("资料库")
            .searchable(text: $searchText, prompt: "搜索标题、备注、分类")
            .onChange(of: selectedPhotoItems) { _, newValue in
                guard !newValue.isEmpty else { return }
                Task {
                    await importPhotos(from: newValue)
                }
            }
            .alert(item: $importAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("知道了"))
                )
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("添加图片", systemImage: "plus")
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        HStack {
            Picker("分类", selection: $selectedCategory) {
                ForEach(ReferencePhotoFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            Text("共 \(filteredItems.count) 项")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var filteredItems: [ReferencePhoto] {
        store.sortedItems.filter { item in
            matchesCategory(item) && matchesSearch(item)
        }
    }

    private var emptyDescription: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "试试更换关键词，或者切换分类筛选。"
        }

        return "把身份证、合同截图、充电桩二维码等重要图片集中放在这里，方便分类和快速查找。"
    }

    private func matchesCategory(_ item: ReferencePhoto) -> Bool {
        switch selectedCategory {
        case .all:
            return true
        case .category(let category):
            return item.category == category
        }
    }

    private func matchesSearch(_ item: ReferencePhoto) -> Bool {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return true }
        return item.searchableText.localizedCaseInsensitiveContains(keyword)
    }

    private func importPhotos(from items: [PhotosPickerItem]) async {
        var imageDataList: [Data] = []
        var failedCount = 0

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty
                else {
                    failedCount += 1
                    continue
                }
                imageDataList.append(data)
            } catch {
                failedCount += 1
            }
        }

        if !imageDataList.isEmpty {
            store.addItems(imageDataList: imageDataList)
        }

        selectedPhotoItems = []

        guard failedCount > 0 else { return }
        importAlert = ReferencePhotoImportAlert(
            title: "部分图片导入失败",
            message: "成功导入 \(imageDataList.count) 张，失败 \(failedCount) 张。"
        )
    }
}

private struct ReferencePhotoCard: View {
    let item: ReferencePhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotePhotoThumbnailView(imageData: item.imageData)
                .frame(height: 160)

            Label(item.category.title, systemImage: item.category.iconName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(item.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            if !item.trimmedNotes.isEmpty {
                Text(item.trimmedNotes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private enum ReferencePhotoFilter: Hashable, CaseIterable, Identifiable {
    case all
    case category(ReferencePhotoCategory)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .category(let category):
            return category.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .category(let category):
            return category.title
        }
    }

    static var allCases: [ReferencePhotoFilter] {
        [.all] + ReferencePhotoCategory.allCases.map(Self.category)
    }
}

private struct ReferencePhotoImportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ReferencePhotoDetailView: View {
    @ObservedObject var store: ReferencePhotoStore
    let itemID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var draft: ReferencePhoto?
    @State private var showingDeleteAlert = false
    @State private var weChatAlert: WeChatAlert?
    @State private var actionAlert: ReferencePhotoActionAlert?
    @State private var detectedQRCodeStrings: [String] = []
    #if os(iOS)
        @State private var shareSheetImage: UIImage?
        @State private var zhuangXiaoMengSchemaURLs: [String: URL] = [:]
        @State private var zhuangXiaoMengFallbackSchemaURLs: [String: URL] = [:]
        @State private var zhuangXiaoMengLoadingCodes: Set<String> = []
        @State private var zhuangXiaoMengErrors: [String: String] = [:]
        @State private var activeWeChatSchemaURL: URL? = nil
    #endif

    private let qrCodeRecognizer = QRCodeRecognizer()

    var body: some View {
        Group {
            if let draft {
                Form {
                    Section {
                        NotePhotoThumbnailView(
                            imageData: draft.imageData, cornerRadius: 20, contentMode: .fit
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 280)
                    }

                    Section {
                        TextField("标题", text: binding(for: \.title))

                        Picker("分类", selection: binding(for: \.category)) {
                            ForEach(ReferencePhotoCategory.allCases) { category in
                                Label(category.title, systemImage: category.iconName)
                                    .tag(category)
                            }
                        }

                        TextField("备注", text: binding(for: \.notes), axis: .vertical)
                            .lineLimit(3...6)
                    } header: {
                        Text("资料信息")
                    } footer: {
                        Text(draft.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if draft.isQRCodeReference || !detectedQRCodeStrings.isEmpty {
                        Section {
                            if detectedQRCodeStrings.isEmpty {
                                Text("当前图片里还没有识别到二维码内容。")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(detectedQRCodeStrings.enumerated()), id: \.offset) {
                                    index, code in
                                    qrCodeResultView(index: index, code: code)
                                        .padding(.vertical, 4)
                                }
                            }

                            #if os(iOS)
                                Button {
                                    shareCurrentImage()
                                } label: {
                                    Label("分享当前图片到微信", systemImage: "square.and.arrow.up")
                                }

                                Button {
                                    Task {
                                        await saveCurrentImageToPhotoLibrary()
                                    }
                                } label: {
                                    Label("保存图片到相册（备用）", systemImage: "square.and.arrow.down")
                                }

                                Button {
                                    openWeChatScanner()
                                } label: {
                                    Label("打开微信扫一扫（扫现场码）", systemImage: "qrcode.viewfinder")
                                }
                            #endif
                        } header: {
                            Text("二维码识别")
                        } footer: {
                            #if os(iOS)
                                Text(
                                    "ChargeHub 会先尝试直接识别当前图片中的二维码内容。像桩盟这类已接入规则的平台，会优先生成“微信小程序直达”按钮；其他依赖微信环境的二维码，仍建议先点“分享当前图片到微信”，必要时再用“保存图片到相册（备用）”。"
                                )
                            #else
                                Text("ChargeHub 会自动解析当前资料图片中的二维码内容；部分依赖微信生态的二维码仍需在微信内处理。")
                            #endif
                        }
                    }

                    Section {
                        Button("保存并返回") {
                            save()
                        }

                        Button("删除图片", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    }
                }
                .navigationTitle(draft.displayTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("保存") {
                            save()
                        }
                    }
                }
                .alert(item: $weChatAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("知道了"))
                    )
                }
                #if os(iOS)
                    .sheet(
                        isPresented: Binding(
                            get: { shareSheetImage != nil },
                            set: { if !$0 { shareSheetImage = nil } }
                        )
                    ) {
                        if let shareSheetImage {
                            ActivityView(items: [shareSheetImage])
                        }
                    }
                #endif
                .alert(item: $actionAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("知道了"))
                    )
                }
                .alert("删除这张图片？", isPresented: $showingDeleteAlert) {
                    Button("删除", role: .destructive) {
                        store.delete(id: itemID)
                        dismiss()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("删除后无法恢复。")
                }
                .task(id: draft.id) {
                    let detectedCodes = qrCodeRecognizer.detectStrings(in: draft.imageData)
                    detectedQRCodeStrings = detectedCodes
                    await resolveSupportedMiniProgramLinks(for: detectedCodes)
                }
            } else {
                ContentUnavailableView(
                    "图片不存在",
                    systemImage: "photo",
                    description: Text("它可能已被删除。")
                )
            }
        }
        .task(id: itemID) {
            draft = store.item(withID: itemID)
        }
    }

    private func binding<Value>(for keyPath: WritableKeyPath<ReferencePhoto, Value>) -> Binding<
        Value
    > {
        Binding(
            get: { draft![keyPath: keyPath] },
            set: { draft![keyPath: keyPath] = $0 }
        )
    }

    private func save() {
        guard let draft else { return }
        store.update(draft)
        dismiss()
    }

    private func copyToPasteboard(_ text: String) {
        #if os(iOS)
            UIPasteboard.general.string = text
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func isDirectlyOpenableQRCode(_ code: String) -> Bool {
        guard let url = URL(string: code), let scheme = url.scheme else {
            return false
        }

        return ["http", "https"].contains(scheme.lowercased())
    }

    @ViewBuilder
    private func qrCodeResultView(index: Int, code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("识别结果 \(index + 1)")
                .font(.subheadline.weight(.semibold))

            Text(code)
                .textSelection(.enabled)
                .font(.body.monospaced())

            HStack {
                Button("复制") {
                    copyToPasteboard(code)
                    actionAlert = ReferencePhotoActionAlert(
                        title: "已复制",
                        message: "二维码内容已经复制到剪贴板。"
                    )
                }

                if let url = URL(string: code), url.scheme != nil {
                    Button(isZhuangXiaoMengLink(code) ? "打开原始链接" : "打开链接") {
                        openURL(url)
                    }
                }
            }
            .buttonStyle(.bordered)

            if let deviceCode = zhuangXiaoMengDeviceCode(from: code) {
                zhuangXiaoMengResultView(code: code, deviceCode: deviceCode)
            } else if !isDirectlyOpenableQRCode(code) {
                Label("这类二维码通常需要在微信内识别或处理。", systemImage: "message.badge.waveform")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func zhuangXiaoMengResultView(code: String, deviceCode: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("已识别为桩盟二维码", systemImage: "bolt.car")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)

            Text("设备码：\(deviceCode)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            HStack {
                Button("复制设备码") {
                    copyToPasteboard(deviceCode)
                    actionAlert = ReferencePhotoActionAlert(
                        title: "已复制设备码",
                        message: "桩盟设备码已经复制到剪贴板。"
                    )
                }

                #if os(iOS)
                    if let schemaURL = zhuangXiaoMengSchemaURLs[code] {
                        Button("复制直达地址") {
                            copyToPasteboard(schemaURL.absoluteString)
                            actionAlert = ReferencePhotoActionAlert(
                                title: "已复制直达地址",
                                message: "请粘贴到微信聊天中点击打开，微信会弹出“即将打开桩小盟+小程序”的确认页。"
                            )
                        }

                        Button("复制并打开微信") {
                            copyToPasteboard(schemaURL.absoluteString)
                            openWeChatHome()
                        }
                    } else if zhuangXiaoMengLoadingCodes.contains(code) {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("生成微信直达") {
                            Task {
                                await resolveZhuangXiaoMengMiniProgramURLIfNeeded(for: code)
                            }
                        }
                    }
                #endif
            }
            .buttonStyle(.bordered)

            #if os(iOS)
                if zhuangXiaoMengLoadingCodes.contains(code) {
                    Text("正在向桩盟接口请求微信小程序直达地址…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let schemaURL = zhuangXiaoMengSchemaURLs[code] {
                    Text("从应用或浏览器直接拉起微信可能进入体验版；如需稳定进入正式版，请复制直达地址到微信聊天中点击打开。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(schemaURL.absoluteString)
                        .textSelection(.enabled)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)

                    Button("复制原始二维码链接") {
                        copyToPasteboard(code)
                        actionAlert = ReferencePhotoActionAlert(
                            title: "已复制原始二维码链接",
                            message: "桩盟原始二维码链接已经复制到剪贴板。"
                        )
                    }
                    .buttonStyle(.bordered)

                } else if let errorMessage = zhuangXiaoMengErrors[code] {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            #else
                Text("该平台的微信小程序直达仅支持在 iPhone 上使用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            #endif
        }
        .padding(10)
        .background(
            .quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func isZhuangXiaoMengLink(_ code: String) -> Bool {
        guard let url = URL(string: code) else { return false }
        return url.host?.lowercased() == "zxm.xyseeker.com" && url.path == "/qrcode/device"
    }

    private func zhuangXiaoMengDeviceCode(from code: String) -> String? {
        guard let url = URL(string: code),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        guard url.host?.lowercased() == "zxm.xyseeker.com", url.path == "/qrcode/device" else {
            return nil
        }

        return components.queryItems?.first(where: { $0.name == "onekey" })?.value
    }

    private func resolveSupportedMiniProgramLinks(for codes: [String]) async {
        #if os(iOS)
            for code in codes {
                await resolveZhuangXiaoMengMiniProgramURLIfNeeded(for: code)
            }
        #endif
    }

    #if os(iOS)
        private func shareCurrentImage() {
            guard let draft, let image = UIImage(data: draft.imageData) else {
                actionAlert = ReferencePhotoActionAlert(
                    title: "无法分享",
                    message: "当前图片暂时无法转换为可分享的格式。"
                )
                return
            }

            shareSheetImage = image
        }
    #endif

    private func openWeChatScanner() {
        #if os(iOS)
            guard let url = URL(string: "weixin://scanqrcode") else { return }
            UIApplication.shared.open(url, options: [:]) { success in
                guard !success else { return }
                weChatAlert = WeChatAlert(
                    title: "无法打开微信",
                    message: "请确认当前设备已安装微信，并允许从 ChargeHub 跳转。"
                )
            }
        #endif
    }

    #if os(iOS)
        private func openWeChatURL(_ url: URL) {
            UIApplication.shared.open(url, options: [:]) { success in
                guard !success else { return }
                weChatAlert = WeChatAlert(
                    title: "无法打开微信小程序",
                    message: "请确认当前设备已安装微信，并允许从 ChargeHub 跳转。"
                )
            }
        }

        private func openWeChatHome() {
            guard let url = URL(string: "weixin://") else { return }
            UIApplication.shared.open(url, options: [:]) { success in
                guard !success else { return }
                weChatAlert = WeChatAlert(
                    title: "无法打开微信",
                    message: "请确认当前设备已安装微信，并允许从 ChargeHub 跳转。"
                )
            }
        }

        private func resolveZhuangXiaoMengMiniProgramURLIfNeeded(for code: String) async {
            guard let deviceCode = zhuangXiaoMengDeviceCode(from: code) else { return }
            guard zhuangXiaoMengSchemaURLs[code] == nil else { return }
            guard !zhuangXiaoMengLoadingCodes.contains(code) else { return }

            zhuangXiaoMengLoadingCodes.insert(code)
            zhuangXiaoMengErrors[code] = nil
            defer { zhuangXiaoMengLoadingCodes.remove(code) }

            do {
                let result = try await fetchZhuangXiaoMengMiniProgramURLs(deviceCode: deviceCode)
                zhuangXiaoMengSchemaURLs[code] = result.preferredURL
                zhuangXiaoMengFallbackSchemaURLs[code] = result.fallbackURL
            } catch {
                zhuangXiaoMengErrors[code] = error.localizedDescription
            }
        }

        private func fetchZhuangXiaoMengMiniProgramURLs(deviceCode: String) async throws
            -> ZhuangXiaoMengMiniProgramURLs
        {
            let appID = try await fetchZhuangXiaoMengMiniProgramAppID(deviceCode: deviceCode)
            let preferredURL = try await fetchZhuangXiaoMengFallbackMiniProgramURL(
                appID: appID,
                deviceCode: deviceCode
            )
            let fallbackURL = try? makeReleaseMiniProgramURL(appID: appID, deviceCode: deviceCode)

            return ZhuangXiaoMengMiniProgramURLs(
                preferredURL: preferredURL, fallbackURL: fallbackURL)
        }

        private func makeReleaseMiniProgramURL(appID: String, deviceCode: String) throws -> URL {
            var components = URLComponents()
            components.scheme = "weixin"
            components.host = "dl"
            components.path = "/business/"
            components.queryItems = [
                URLQueryItem(name: "appid", value: appID),
                URLQueryItem(name: "path", value: "pages/deviceDetail/index"),
                URLQueryItem(name: "query", value: "params1=\(deviceCode)"),
                URLQueryItem(name: "env_version", value: "release"),
            ]

            guard let url = components.url else {
                throw ZhuangXiaoMengMiniProgramError.invalidRequest
            }

            return url
        }

        private func fetchZhuangXiaoMengFallbackMiniProgramURL(appID: String, deviceCode: String)
            async throws -> URL
        {
            var schemaComponents = URLComponents(
                string: "https://zxm.xyseeker.com/gateway/wechat/api/wechat/member/getMiniAppSchema"
            )
            schemaComponents?.queryItems = [
                URLQueryItem(name: "appId", value: appID),
                URLQueryItem(name: "path", value: "pages/deviceDetail/index"),
                URLQueryItem(name: "query", value: "params1=\(deviceCode)"),
            ]

            guard let schemaURL = schemaComponents?.url else {
                throw ZhuangXiaoMengMiniProgramError.invalidRequest
            }

            let data = try await fetchData(from: schemaURL)
            let payload = try JSONSerialization.jsonObject(with: data)

            if let schemaString = findFirstString(in: payload, prefix: "weixin://dl/business/"),
                let resolvedURL = URL(string: schemaString)
            {
                return resolvedURL
            }

            throw ZhuangXiaoMengMiniProgramError.schemaNotFound
        }

        private func fetchZhuangXiaoMengMiniProgramAppID(deviceCode: String) async throws -> String
        {
            var components = URLComponents(
                string: "https://zxm.xyseeker.com/gateway/seeker/api/wechartConfig")
            components?.queryItems = [
                URLQueryItem(name: "deviceCode", value: deviceCode),
                URLQueryItem(name: "scanSource", value: "Wechat"),
            ]

            guard let configURL = components?.url else {
                throw ZhuangXiaoMengMiniProgramError.invalidRequest
            }

            let data = try await fetchData(from: configURL)
            let payload = try JSONSerialization.jsonObject(with: data)

            if let appID = findString(in: payload, key: "wxMiniAppId"), !appID.isEmpty {
                return appID
            }

            throw ZhuangXiaoMengMiniProgramError.appIDNotFound
        }

        private func fetchData(from url: URL) async throws -> Data {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                throw ZhuangXiaoMengMiniProgramError.serverUnavailable
            }
            return data
        }

        private func findString(in json: Any, key targetKey: String) -> String? {
            if let dictionary = json as? [String: Any] {
                if let value = dictionary[targetKey] as? String {
                    return value
                }

                for value in dictionary.values {
                    if let found = findString(in: value, key: targetKey) {
                        return found
                    }
                }
            } else if let array = json as? [Any] {
                for item in array {
                    if let found = findString(in: item, key: targetKey) {
                        return found
                    }
                }
            }

            return nil
        }

        private func findFirstString(in json: Any, prefix: String) -> String? {
            if let string = json as? String, string.hasPrefix(prefix) {
                return string
            }

            if let dictionary = json as? [String: Any] {
                for value in dictionary.values {
                    if let found = findFirstString(in: value, prefix: prefix) {
                        return found
                    }
                }
            } else if let array = json as? [Any] {
                for item in array {
                    if let found = findFirstString(in: item, prefix: prefix) {
                        return found
                    }
                }
            }

            return nil
        }

        private func saveCurrentImageToPhotoLibrary() async {
            guard let draft else { return }

            do {
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    throw ReferencePhotoSaveError.permissionDenied
                }

                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: draft.imageData, options: nil)
                    }) { success, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if success {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: ReferencePhotoSaveError.saveFailed)
                        }
                    }
                }

                actionAlert = ReferencePhotoActionAlert(
                    title: "已保存到相册",
                    message: "现在可以到微信扫一扫里从相册选择这张图片进行识别。"
                )
            } catch {
                actionAlert = ReferencePhotoActionAlert(
                    title: "保存失败",
                    message: error.localizedDescription
                )
            }
        }
    #endif
}

private struct WeChatAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct ReferencePhotoActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum ReferencePhotoSaveError: LocalizedError {
    case permissionDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "请允许 ChargeHub 添加照片到相册，之后再试。"
        case .saveFailed:
            return "保存到相册失败，请稍后重试。"
        }
    }
}

private struct ZhuangXiaoMengMiniProgramURLs {
    let preferredURL: URL
    let fallbackURL: URL?
}

private enum ZhuangXiaoMengMiniProgramError: LocalizedError {
    case invalidRequest
    case appIDNotFound
    case schemaNotFound
    case serverUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "生成桩盟微信直达地址失败，请稍后重试。"
        case .appIDNotFound:
            return "未能从桩盟接口获取小程序 AppID。"
        case .schemaNotFound:
            return "未能从桩盟接口获取微信直达地址。"
        case .serverUnavailable:
            return "桩盟服务暂时不可用，请稍后再试。"
        }
    }
}

#if os(iOS)
    private struct ActivityView: UIViewControllerRepresentable {
        let items: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: nil)
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context)
        {}
    }
#endif

#Preview {
    ReferencePhotosView(store: ReferencePhotoStore(previewItems: ReferencePhoto.previewItems))
}
