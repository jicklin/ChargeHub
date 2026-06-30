import SwiftUI

struct DeviceRowView: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.category.iconName)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 38, height: 38)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)

                Text("\(device.category.title) · 上次充电 \(device.lastChargedDateText) · \(device.chargeLevelText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.12), in: Capsule())
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
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

    private var statusColor: Color {
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
    List(Device.previewDevices) { device in
        DeviceRowView(device: device)
    }
}
