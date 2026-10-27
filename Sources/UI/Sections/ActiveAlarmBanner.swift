import SwiftUI

public struct ActiveAlarmBanner: View {
    @ObservedObject var schedule: ScheduleManager

    public init(schedule: ScheduleManager = .shared) {
        self.schedule = schedule
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .foregroundColor(.red)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 1) {
                Text("ALARM ACTIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
                Text(schedule.activeAlarmDescription ?? "Alarm triggering")
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Dismiss") {
                withAnimation {
                    schedule.dismissAlarm()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
