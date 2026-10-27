import SwiftUI

public struct AlarmsSection: View {
    @ObservedObject var schedule: ScheduleManager
    @ObservedObject var vm: MainViewModel

    public init(schedule: ScheduleManager = .shared, vm: MainViewModel) {
        self.schedule = schedule
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SCHEDULED ALARMS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    vm.startNewAlarm()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if schedule.alarms.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "alarm")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No alarms scheduled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Button("Add 9:00 AM Alarm") {
                        schedule.addAlarm(BulbAlarm(hour: 9, minute: 0, repeatOption: .daily, mode: .hardwareAlarm, durationSeconds: 30))
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 7) {
                        ForEach(schedule.alarms) { alarm in
                            alarmRow(alarm)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func alarmRow(_ alarm: BulbAlarm) -> some View {
        HStack(spacing: 8) {
            Image(systemName: alarm.mode.icon)
                .font(.system(size: 13))
                .foregroundColor(alarm.isEnabled ? Color.accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(alarm.formattedTime)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(alarm.isEnabled ? .primary : .secondary)

                    Text(alarm.repeatOption.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }

                Text(alarm.mode.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Test Button
            Button {
                schedule.triggerAlarm(alarm)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Test this alarm now (runs for 30s or until dismissed)")

            // Edit Button
            Button {
                vm.startEditingAlarm(alarm)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit alarm settings")

            // Enable Toggle
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { val in
                    var updated = alarm
                    updated.isEnabled = val
                    schedule.updateAlarm(updated)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)

            // Delete Button
            Button {
                schedule.deleteAlarm(id: alarm.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 8), interactive: true)
    }
}
