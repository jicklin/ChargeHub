import SwiftUI

struct TripsContentView: View {
    @ObservedObject var store: TripStore
    @State private var showingAddTrip = false

    var body: some View {
        List {
            Section("统计") {
                LabeledContent("旅行数", value: "\(store.trips.count)")
                LabeledContent("总花销", value: currencyText(store.totalExpense))

                ForEach(store.expensesByCategory, id: \.category) { item in
                    LabeledContent(item.category.title, value: currencyText(item.amount))
                }
            }

            Section("旅行") {
                if store.sortedTrips.isEmpty {
                    ContentUnavailableView(
                        "还没有旅行记录",
                        systemImage: "airplane.departure",
                        description: Text("记录每次旅行的交通、住宿、餐饮等花销，并查看统计分析。")
                    )
                } else {
                    ForEach(store.sortedTrips) { trip in
                        NavigationLink {
                            TripDetailView(store: store, tripID: trip.id)
                        } label: {
                            TripRowView(trip: trip)
                        }
                    }
                    .onDelete { offsets in
                        let trips = store.sortedTrips
                        for offset in offsets {
                            store.deleteTrip(id: trips[offset].id)
                        }
                    }
                }
            }
        }
        .navigationTitle("旅行")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTrip = true
                } label: {
                    Label("添加旅行", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTrip) {
            NavigationStack {
                TripFormView(store: store)
            }
        }
    }
}

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.trimmedTitle.isEmpty ? "未命名旅行" : trip.trimmedTitle)
                    .font(.headline)
                Spacer()
                Text(currencyText(trip.totalExpense))
                    .font(.headline)
            }

            Text(
                [trip.trimmedDestination, tripDateRangeText].filter { !$0.isEmpty }.joined(
                    separator: " · ")
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("\(trip.expenses.count) 笔花销 · 日均 \(currencyText(trip.averageDailyExpense))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var tripDateRangeText: String {
        "\(shortDateText(trip.startDate)) - \(shortDateText(trip.endDate))"
    }
}

struct TripDetailView: View {
    @ObservedObject var store: TripStore
    let tripID: UUID
    @State private var showingEditTrip = false
    @State private var showingAddExpense = false
    @State private var editingExpense: TripExpense?

    private var trip: Trip? {
        store.trip(withID: tripID)
    }

    var body: some View {
        Group {
            if let trip {
                List {
                    Section("统计") {
                        LabeledContent("总花销", value: currencyText(trip.totalExpense))
                        LabeledContent("天数", value: "\(trip.dayCount) 天")
                        LabeledContent("日均", value: currencyText(trip.averageDailyExpense))
                        ForEach(trip.expensesByCategory, id: \.category) { item in
                            LabeledContent(item.category.title, value: currencyText(item.amount))
                        }
                    }

                    Section("花销明细") {
                        if trip.expenses.isEmpty {
                            Text("还没有记录花销")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(trip.expenses.sorted { $0.date > $1.date }) { expense in
                                ExpenseRowView(expense: expense)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingExpense = expense
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            store.deleteExpense(id: expense.id, in: trip.id)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .navigationTitle(trip.trimmedTitle.isEmpty ? "旅行详情" : trip.trimmedTitle)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            showingAddExpense = true
                        } label: {
                            Label("添加花销", systemImage: "plus")
                        }
                        Button("编辑") {
                            showingEditTrip = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditTrip) {
                    NavigationStack {
                        TripFormView(store: store, existingTrip: trip)
                    }
                }
                .sheet(isPresented: $showingAddExpense) {
                    NavigationStack {
                        ExpenseFormView(store: store, tripID: trip.id)
                    }
                }
                .sheet(item: $editingExpense) { expense in
                    NavigationStack {
                        ExpenseFormView(store: store, tripID: trip.id, existingExpense: expense)
                    }
                }
            } else {
                ContentUnavailableView("旅行不存在", systemImage: "airplane")
            }
        }
    }
}

struct ExpenseRowView: View {
    let expense: TripExpense

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.iconName)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.trimmedTitle.isEmpty ? expense.category.title : expense.trimmedTitle)
                    .font(.subheadline.weight(.semibold))
                Text("\(expense.category.title) · \(shortDateText(expense.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(currencyText(expense.amount))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 3)
    }
}

struct TripFormView: View {
    @ObservedObject var store: TripStore
    let existingTrip: Trip?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String

    init(store: TripStore, existingTrip: Trip? = nil) {
        self.store = store
        self.existingTrip = existingTrip
        _title = State(initialValue: existingTrip?.title ?? "")
        _destination = State(initialValue: existingTrip?.destination ?? "")
        _startDate = State(initialValue: existingTrip?.startDate ?? .now)
        _endDate = State(initialValue: existingTrip?.endDate ?? .now)
        _notes = State(initialValue: existingTrip?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("旅行名称", text: $title)
                TextField("目的地", text: $destination)
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            }
            Section("备注") {
                TextField("可选备注", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(existingTrip == nil ? "添加旅行" : "编辑旅行")
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
        let normalizedEndDate = max(startDate, endDate)
        let trip = Trip(
            id: existingTrip?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: normalizedEndDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            expenses: existingTrip?.expenses ?? [],
            createdAt: existingTrip?.createdAt ?? .now
        )

        if existingTrip == nil {
            store.addTrip(trip)
        } else {
            store.updateTrip(trip)
        }
        dismiss()
    }
}

struct ExpenseFormView: View {
    @ObservedObject var store: TripStore
    let tripID: UUID
    let existingExpense: TripExpense?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var amountText: String
    @State private var category: TripExpenseCategory
    @State private var date: Date
    @State private var notes: String

    init(store: TripStore, tripID: UUID, existingExpense: TripExpense? = nil) {
        self.store = store
        self.tripID = tripID
        self.existingExpense = existingExpense
        _title = State(initialValue: existingExpense?.title ?? "")
        _amountText = State(
            initialValue: existingExpense.map { currencyInputText($0.amount) } ?? "")
        _category = State(initialValue: existingExpense?.category ?? .other)
        _date = State(initialValue: existingExpense?.date ?? .now)
        _notes = State(initialValue: existingExpense?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("花销") {
                TextField("名称", text: $title)
                TextField("金额", text: $amountText)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                Picker("分类", selection: $category) {
                    ForEach(TripExpenseCategory.allCases) { category in
                        Label(category.title, systemImage: category.iconName).tag(category)
                    }
                }
                DatePicker("日期", selection: $date, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            }
            Section("备注") {
                TextField("可选备注", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(existingExpense == nil ? "添加花销" : "编辑花销")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(parsedAmount == nil)
            }
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let expense = TripExpense(
            id: existingExpense?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            category: category,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if existingExpense == nil {
            store.addExpense(expense, to: tripID)
        } else {
            store.updateExpense(expense, in: tripID)
        }
        dismiss()
    }
}

private func currencyText(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    return formatter.string(from: amount as NSDecimalNumber) ?? "¥0.00"
}

private func currencyInputText(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    return formatter.string(from: amount as NSDecimalNumber) ?? ""
}

private func shortDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.dateFormat = "M月d日"
    return formatter.string(from: date)
}

#Preview {
    NavigationStack {
        TripsContentView(store: TripStore(previewTrips: Trip.previewItems))
    }
}
