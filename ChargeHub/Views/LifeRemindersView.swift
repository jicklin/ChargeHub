import SwiftUI

struct LifeRemindersView: View {
    @ObservedObject var store: LifeReminderStore
    @State private var showingAddReminder = false
    @State private var editingReminder: LifeReminder?

    var body: some View {
        NavigationStack {
            List {
                reminderSection(
                    title: "需要关注", reminders: store.dueReminders + store.upcomingReminders)
                reminderSection(title: "全部提醒", reminders: store.activeReminders)
            }
            .navigationTitle("提醒")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddReminder = true
                    } label: {
                        Label("添加提醒", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                NavigationStack {
                    LifeReminderFormView(store: store)
                }
            }
            .sheet(item: $editingReminder) { reminder in
                NavigationStack {
                    LifeReminderFormView(store: store, existingReminder: reminder)
                }
            }
        }
    }

    @ViewBuilder
    private func reminderSection(title: String, reminders: [LifeReminder]) -> some View {
        if reminders.isEmpty {
            if title == "全部提醒" {
                Section {
                    ContentUnavailableView(
                        "还没有提醒",
                        systemImage: "calendar.badge.plus",
                        description: Text("记录体检、证件办理、生日等需要提前提醒的事项。")
                    )
                }
            }
        } else {
            Section(title) {
                ForEach(reminders) { reminder in
                    LifeReminderRowView(reminder: reminder)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingReminder = reminder
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteReminder(id: reminder.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            if reminder.kind == .event {
                                Button {
                                    store.toggleCompleted(id: reminder.id)
                                } label: {
                                    Label(
                                        reminder.isCompleted ? "恢复" : "完成", systemImage: "checkmark"
                                    )
                                }
                                .tint(.green)
                            }
                        }
                }
            }
        }
    }
}

struct LifeReminderRowView: View {
    let reminder: LifeReminder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.kind.iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.trimmedTitle.isEmpty ? reminder.kind.title : reminder.trimmedTitle)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !reminder.trimmedNotes.isEmpty {
                    Text(reminder.trimmedNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(stateText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        switch reminder.kind {
        case .event:
            return "\(reminder.displayDateText) · 提前 \(reminder.advanceNoticeDays) 天提醒"
        case .birthday:
            return "每年 \(birthdayMonthDayText) · 提前 \(reminder.advanceNoticeDays) 天提醒"
        }
    }

    private var birthdayMonthDayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: reminder.date)
    }

    private var stateText: String {
        switch reminder.reminderState() {
        case .overdue(let days): "逾期 \(days) 天"
        case .dueToday: "今天"
        case .upcoming(let days): "\(days) 天后"
        case .future(let days): "\(days) 天后"
        }
    }

    private var iconColor: Color {
        switch reminder.reminderState() {
        case .overdue, .dueToday: .red
        case .upcoming: .orange
        case .future: .accentColor
        }
    }
}

struct LifeReminderFormView: View {
    @ObservedObject var store: LifeReminderStore
    let existingReminder: LifeReminder?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var kind: LifeReminderKind
    @State private var date: Date
    @State private var advanceNoticeDays: Int
    @State private var notes: String

    init(store: LifeReminderStore, existingReminder: LifeReminder? = nil) {
        self.store = store
        self.existingReminder = existingReminder
        _title = State(initialValue: existingReminder?.title ?? "")
        _kind = State(initialValue: existingReminder?.kind ?? .event)
        _date = State(initialValue: existingReminder?.date ?? .now)
        _advanceNoticeDays = State(initialValue: existingReminder?.advanceNoticeDays ?? 3)
        _notes = State(initialValue: existingReminder?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField(kind == .birthday ? "姓名 / 生日对象" : "事项标题", text: $title)
                Picker("类型", selection: $kind) {
                    ForEach(LifeReminderKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.iconName).tag(kind)
                    }
                }
                DatePicker(
                    kind == .birthday ? "生日" : "日期", selection: $date, displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            }

            Section("提醒") {
                Stepper("提前 \(advanceNoticeDays) 天提醒", value: $advanceNoticeDays, in: 0...60)
            }

            Section("备注") {
                TextField("可选备注", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(existingReminder == nil ? "添加提醒" : "编辑提醒")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let reminder = LifeReminder(
            id: existingReminder?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            date: date,
            advanceNoticeDays: advanceNoticeDays,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: existingReminder?.isCompleted ?? false,
            createdAt: existingReminder?.createdAt ?? .now
        )

        if existingReminder == nil {
            store.addReminder(reminder)
        } else {
            store.updateReminder(reminder)
        }
        dismiss()
    }
}

#Preview {
    LifeRemindersView(store: LifeReminderStore(previewReminders: LifeReminder.previewItems))
}
