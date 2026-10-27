import SwiftUI

public struct AddAlarmSheetView: View {
    @ObservedObject var schedule: ScheduleManager
    @ObservedObject var vm: MainViewModel

    public init(schedule: ScheduleManager = .shared, vm: MainViewModel) {
        self.schedule = schedule
        self.vm = vm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(vm.editingAlarmId == nil ? "New Alarm / Schedule" : "Edit Alarm / Schedule")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(vm.editingAlarmId == nil ? "Add" : "Save") {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: vm.newAlarmTime)
                    let id = vm.editingAlarmId ?? UUID()
                    let alarm = BulbAlarm(
                        id: id,
                        isEnabled: true,
                        hour: comps.hour ?? 9,
                        minute: comps.minute ?? 0,
                        repeatOption: vm.newAlarmRepeat,
                        mode: vm.newAlarmMode,
                        designatedBrightness: vm.newAlarmBrightness,
                        durationSeconds: 30
                    )
                    schedule.updateAlarm(alarm)
                    vm.showingAlarmSheet = false
                }
                .controlSize(.small)
            }

            // Time Picker
            DatePicker("Time", selection: $vm.newAlarmTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.stepperField)

            // Repeat Picker
            Picker("Repeat", selection: $vm.newAlarmRepeat) {
                ForEach(AlarmRepeat.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }

            // Alarm Action
            Picker("Action", selection: $vm.newAlarmMode) {
                ForEach(AlarmMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Text(vm.newAlarmMode.summary)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Brightness
            if vm.newAlarmMode != .turnOff {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Target Brightness")
                            .font(.system(size: 11))
                        Spacer()
                        Text("\(Int(vm.newAlarmBrightness))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    Slider(value: $vm.newAlarmBrightness, in: 10...100, step: 5)
                }
            }

            HStack {
                Button("Cancel") {
                    vm.showingAlarmSheet = false
                }
                .controlSize(.small)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
