import SwiftUI

public struct AddAlarmSheetView: View {
    @ObservedObject var schedule: ScheduleManager
    @ObservedObject var vm: MainViewModel

    public init(schedule: ScheduleManager = .shared, vm: MainViewModel) {
        self.schedule = schedule
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Header with Cancel and Save
            HStack {
                Button("Cancel") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        vm.showingAlarmSheet = false
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Spacer()

                Text(vm.editingAlarmId == nil ? "New Alarm" : "Edit Alarm")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Button(vm.editingAlarmId == nil ? "Add" : "Save") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: vm.newAlarmTime)
                        let id = vm.editingAlarmId ?? UUID()
                        var alarm = schedule.alarms.first(where: { $0.id == id })
                            ?? BulbAlarm(id: id, durationSeconds: 30)
                        alarm.isEnabled = true
                        alarm.hour = comps.hour ?? 9
                        alarm.minute = comps.minute ?? 0
                        alarm.repeatOption = vm.newAlarmRepeat
                        alarm.mode = vm.newAlarmMode
                        alarm.designatedBrightness = vm.newAlarmBrightness
                        schedule.updateAlarm(alarm)
                        vm.showingAlarmSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }
            .padding(.bottom, 2)

            // Content Form inside a sleek glass card
            VStack(spacing: 8) {
                // Time Row
                HStack {
                    Text("Time")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    DatePicker("", selection: $vm.newAlarmTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                }

                Divider().opacity(0.4)

                // Repeat Row
                HStack {
                    Text("Repeat")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Picker("", selection: $vm.newAlarmRepeat) {
                        ForEach(AlarmRepeat.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 120)
                }

                Divider().opacity(0.4)

                // Action Row
                HStack {
                    Text("Action")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Picker("", selection: $vm.newAlarmMode) {
                        ForEach(AlarmMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 120)
                }

                // Brightness slider (if mode is not turnOff)
                if vm.newAlarmMode != .turnOff {
                    Divider().opacity(0.4)

                    HStack(spacing: 8) {
                        Text("Brightness")
                            .font(.system(size: 11, weight: .medium))
                        Slider(value: $vm.newAlarmBrightness, in: 10...100, step: 5)
                            .controlSize(.mini)
                        Text("\(Int(vm.newAlarmBrightness))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
            .padding(10)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 10), interactive: false)

            Spacer()
        }
        .frame(height: 220)
    }
}
