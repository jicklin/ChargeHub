import SwiftUI

@MainActor
struct DeviceFormView: View {
    @ObservedObject var store: DeviceStore
    let existingDevice: Device?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: DeviceDraft
    @State private var chargeLevelText: String
    @State private var reminderDaysText: String

    init(store: DeviceStore, existingDevice: Device? = nil) {
        self.store = store
        self.existingDevice = existingDevice

        let initialDraft = existingDevice.map(DeviceDraft.init) ?? DeviceDraft()
        _draft = State(initialValue: initialDraft)
        _chargeLevelText = State(initialValue: "\(initialDraft.lastChargeLevel)")
        _reminderDaysText = State(initialValue: "\(initialDraft.remindAfterDays)")
    }

    var body: some View {
        Form {
            Section {
                TextField("设备名称", text: $draft.name)

                Picker("设备类型", selection: $draft.category) {
                    ForEach(DeviceCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }

                DatePicker("上次充电日期", selection: $draft.lastChargedAt, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            } header: {
                Text("基本信息")
            }

            Section {
                Toggle("记录上次充到多少", isOn: $draft.recordChargeLevel)

                if draft.recordChargeLevel {
                    HStack {
                        Text("上次充到")
                        Spacer()

                        HStack(spacing: 0) {
                            adjustButton(
                                systemName: "minus",
                                action: {
                                    adjustChargeLevel(by: -5)
                                })

                            Divider()
                                .frame(height: 24)

                            TextField("0-100", text: $chargeLevelText)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .frame(width: 56)

                            Divider()
                                .frame(height: 24)

                            adjustButton(
                                systemName: "plus",
                                action: {
                                    adjustChargeLevel(by: 5)
                                })
                        }
                        .background(
                            .thinMaterial,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text("%")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                    }
                }
            } header: {
                Text("充电记录")
            }

            Section {
                HStack {
                    Text("超过多少天提醒")
                    Spacer()

                    HStack(spacing: 0) {
                        adjustButton(
                            systemName: "minus",
                            action: {
                                adjustReminderDays(by: -1)
                            })

                        Divider()
                            .frame(height: 24)

                        TextField("1-365", text: $reminderDaysText)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .frame(width: 56)

                        Divider()
                            .frame(height: 24)

                        adjustButton(
                            systemName: "plus",
                            action: {
                                adjustReminderDays(by: 1)
                            })
                    }
                    .background(
                        .thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("天")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)
                }

                Button("使用推荐值：\(draft.category.recommendedReminderDays) 天") {
                    draft.remindAfterDays = draft.category.recommendedReminderDays
                    reminderDaysText = "\(draft.remindAfterDays)"
                }
            } header: {
                Text("提醒")
            } footer: {
                Text("适合提醒长期闲置的相机、备用机、手柄、充电宝等设备。")
            }

            Section {
                TextField("可选备注", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("备注")
            }

            if existingDevice != nil {
                Section {
                    Toggle("归档设备", isOn: $draft.isArchived)
                } header: {
                    Text("其他")
                }
            }
        }
        .navigationTitle(existingDevice == nil ? "添加设备" : "编辑设备")
        .onChange(of: chargeLevelText) { _, newValue in
            applyChargeLevelInput(newValue)
        }
        .onChange(of: reminderDaysText) { _, newValue in
            applyReminderDaysInput(newValue)
        }
        .onChange(of: draft.recordChargeLevel) { _, isEnabled in
            if isEnabled && chargeLevelText.isEmpty {
                chargeLevelText = "\(draft.lastChargeLevel)"
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                }
                .disabled(draft.trimmedName.isEmpty)
            }
        }
    }

    private func save() {
        guard !draft.trimmedName.isEmpty else { return }

        applyChargeLevelInput(chargeLevelText, normalizeDisplay: true)
        applyReminderDaysInput(reminderDaysText, normalizeDisplay: true)

        if let existingDevice {
            store.updateDevice(id: existingDevice.id, with: draft)
        } else {
            store.addDevice(from: draft)
        }

        dismiss()
    }

    @ViewBuilder
    private func adjustButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func adjustChargeLevel(by delta: Int) {
        let normalized = min(max(draft.lastChargeLevel + delta, 0), 100)
        draft.lastChargeLevel = normalized
        chargeLevelText = "\(normalized)"
    }

    private func adjustReminderDays(by delta: Int) {
        let normalized = min(max(draft.remindAfterDays + delta, 1), 365)
        draft.remindAfterDays = normalized
        reminderDaysText = "\(normalized)"
    }

    private func applyChargeLevelInput(_ input: String, normalizeDisplay: Bool = false) {
        let digits = input.filter(\.isNumber)

        if digits != input {
            chargeLevelText = digits
            return
        }

        guard let value = Int(digits) else { return }

        let normalized = min(max(value, 0), 100)
        draft.lastChargeLevel = normalized

        if normalizeDisplay || normalized != value {
            chargeLevelText = "\(normalized)"
        }
    }

    private func applyReminderDaysInput(_ input: String, normalizeDisplay: Bool = false) {
        let digits = input.filter(\.isNumber)

        if digits != input {
            reminderDaysText = digits
            return
        }

        guard let value = Int(digits) else { return }

        let normalized = min(max(value, 1), 365)
        draft.remindAfterDays = normalized

        if normalizeDisplay || normalized != value {
            reminderDaysText = "\(normalized)"
        }
    }
}

#Preview {
    NavigationStack {
        DeviceFormView(store: DeviceStore(previewDevices: Device.previewDevices))
    }
}
