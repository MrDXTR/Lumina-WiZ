import SwiftUI
import AppKit

public struct MainView: View {
    @ObservedObject var wiz = WizService.shared
    @ObservedObject var vm = MainViewModel()
    @ObservedObject var schedule = ScheduleManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            // Active Alarm Alert Banner
            if schedule.isAlarmTriggered {
                activeAlarmBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 3D bulb remains on a transparent background; it bobs only when a control changes.
            Bulb3DView(isOn: wiz.isOn, color: wiz.color, brightness: wiz.brightness, visualChangeToken: wiz.visualChangeToken)
                .frame(height: 130)
                .padding(.bottom, 4)

            // Sleek, Compact Tab Bar (Color | White | Scenes | Alarm)
            customTabBar
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
                .disabled(!wiz.isOn && wiz.activeMode != .alarms)

            // Mode Content View
            Group {
                switch wiz.activeMode {
                case .color:
                    ColorWheelView(selectedColor: $wiz.color) { newColor in
                        wiz.setColor(newColor)
                    }
                    .frame(height: 220)

                case .temperature:
                    temperatureControlView
                        .frame(height: 220)

                case .scenes:
                    scenesGridView
                        .frame(height: 220)

                case .alarms:
                    alarmsControlView
                        .frame(height: 220)
                }
            }
            .padding(.horizontal, 18)
            .disabled(!wiz.isOn && wiz.activeMode != .alarms)
            .opacity((wiz.isOn || wiz.activeMode == .alarms) ? 1.0 : 0.4)

            Divider()
                .padding(.vertical, 6)
                .padding(.horizontal, 16)

            // Brightness Slider
            brightnessSection
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
                .disabled(!wiz.isOn)
                .opacity(wiz.isOn ? 1.0 : 0.4)

            // Error banner if any
            if let errorMsg = wiz.lastErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(errorMsg)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 5)
            }

            // Footer Action Bar
            footerSection
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .padding(.top, 2)
        }
        .frame(width: 330, height: 515)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .overlay(Color.white.opacity(0.035))
        )
        .sheet(isPresented: $vm.showingAlarmSheet) {
            addAlarmSheetView
        }
    }

    // MARK: - Custom Tab Bar (Color | White | Scenes | Alarm)

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BulbControlMode.allCases) { mode in
                let isSelected = wiz.activeMode == mode
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        wiz.selectMode(mode)
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentColor.opacity(0.85))
                                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Philips WiZ Neo")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                HStack(spacing: 5) {
                    Circle()
                        .fill(wiz.isConnected ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(wiz.isConnected ? "Connected • \(wiz.ipAddress)" : (wiz.isScanning ? "Scanning..." : "Offline"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Big tactile Power Button
            Button(action: {
                wiz.togglePower()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            wiz.isOn
                            ? AnyShapeStyle(Color(wiz.color).opacity(0.2))
                            : AnyShapeStyle(Color.primary.opacity(0.08))
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(wiz.isOn ? Color(wiz.color) : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        )

                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(wiz.isOn ? Color(wiz.color) : .secondary)
                }
            }
            .buttonStyle(.plain)
            .shadow(color: wiz.isOn ? Color(wiz.color).opacity(0.4) : .clear, radius: 6, x: 0, y: 1)
        }
    }

    private var activeAlarmBanner: some View {
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

    private var brightnessSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { wiz.brightness },
                    set: { wiz.setBrightness($0) }
                ), in: 10...100, step: 1)
                .accentColor(Color(wiz.color))

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text("\(Int(wiz.brightness))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    // MARK: - Temperature Control View

    private var temperatureControlView: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("Color Temperature")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()

                    // Kelvin Numeric Input Field
                    HStack(spacing: 3) {
                        TextField("3500", text: $vm.tempInputText)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 44)
                            .onSubmit {
                                applyTempFromInput()
                            }

                        Text("K")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
                    )
                }

                // Interactive Gradient Glide Slider with Visible Pointer / Circle Thumb
                kelvinSliderTrack
            }
            .padding(10)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 10), interactive: false)

            // Quick Kelvin Presets
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    tempPresetButton(name: "Candlelight", kelvin: 2200, icon: "flame.fill")
                    tempPresetButton(name: "Warm White", kelvin: 2700, icon: "sun.haze.fill")
                }
                HStack(spacing: 7) {
                    tempPresetButton(name: "Neutral", kelvin: 4000, icon: "sun.dust.fill")
                    tempPresetButton(name: "Daylight", kelvin: 6500, icon: "sun.max.fill")
                }
            }

            Spacer()
        }
        .padding(.top, 4)
        .onAppear {
            vm.syncTemperature(wiz.temperature)
        }
        .onChange(of: wiz.temperature) { newTemp in
            if !vm.isDraggingTemp {
                vm.syncTemperature(newTemp)
            }
        }
    }

    private var kelvinSliderTrack: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let thumbDiameter: CGFloat = 22.0
            let thumbRadius = thumbDiameter / 2.0
            let usableWidth = max(1.0, trackWidth - thumbDiameter)
            let clampedTemp = max(2200.0, min(6500.0, wiz.temperature))
            let progress = CGFloat((clampedTemp - 2200.0) / (6500.0 - 2200.0))
            let thumbX = thumbRadius + progress * usableWidth

            ZStack(alignment: .leading) {
                // Gradient Track
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.58, blue: 0.22), // 2200K
                                Color(red: 1.0, green: 0.82, blue: 0.55), // 3000K
                                Color(red: 1.0, green: 0.95, blue: 0.90), // 4500K
                                Color(red: 0.80, green: 0.90, blue: 1.0)  // 6500K
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )

                // The Draggable Circular Pointer / Thumb
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1.5)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        )

                    // Inner circle showing current Kelvin glow
                    Circle()
                        .fill(Color(wiz.kelvinToColor(clampedTemp)))
                        .frame(width: 13, height: 13)
                }
                .scaleEffect(vm.isDraggingTemp ? 1.18 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: vm.isDraggingTemp)
                .position(x: thumbX, y: 8)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        vm.isDraggingTemp = true
                        let x = value.location.x
                        let ratio = min(max(0.0, (x - thumbRadius) / usableWidth), 1.0)
                        let rawKelvin = 2200.0 + Double(ratio) * 4300.0
                        let roundedKelvin = round(rawKelvin / 25.0) * 25.0
                        wiz.setTemperature(roundedKelvin)
                        vm.syncTemperature(roundedKelvin)
                    }
                    .onEnded { _ in
                        vm.isDraggingTemp = false
                    }
            )
        }
        .frame(height: 22)
    }

    private func applyTempFromInput() {
        if let val = Double(vm.tempInputText.trimmingCharacters(in: .whitespaces)) {
            let clamped = max(2200.0, min(6500.0, val))
            wiz.setTemperature(clamped)
            vm.syncTemperature(clamped)
        } else {
            vm.syncTemperature(wiz.temperature)
        }
    }

    private func tempPresetButton(name: String, kelvin: Double, icon: String) -> some View {
        let isSelected = abs(wiz.temperature - kelvin) < 150
        return Button(action: {
            wiz.setTemperature(kelvin)
            vm.syncTemperature(kelvin)
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scenes Grid View (Dynamic speed + Native bulb execution)

    private var scenesGridView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                // Dynamic Lighting Speed Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "gauge.with.needle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Dynamic Scene Speed")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(Int(wiz.dynamicSpeed))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Slider(value: Binding(
                            get: { wiz.dynamicSpeed },
                            set: { wiz.setSpeed($0) }
                        ), in: 20...100, step: 5)
                        .accentColor(Color(wiz.color))

                        Image(systemName: "hare.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 8), interactive: false)

                // Standalone Dynamic Scenes Header
                HStack {
                    Text("DYNAMIC SCENES (STANDALONE)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "bolt.badge.checkmark.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(wiz.availableScenes.filter { $0.isDynamic }) { scene in
                        let isSelected = wiz.activeSceneId == scene.id
                        Button(action: { wiz.setScene(scene) }) {
                            HStack(spacing: 6) {
                                Image(systemName: scene.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(scene.previewColor))
                                Text(scene.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // White Ambiances
                Text("WHITE AMBIANCES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(wiz.availableScenes.filter { !$0.isDynamic }) { scene in
                        let isSelected = wiz.activeSceneId == scene.id
                        Button(action: { wiz.setScene(scene) }) {
                            HStack(spacing: 6) {
                                Image(systemName: scene.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(scene.previewColor))
                                Text(scene.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Alarms & Schedule View

    private var alarmsControlView: some View {
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

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func alarmRow(_ alarm: BulbAlarm) -> some View {
        HStack(spacing: 8) {
            Image(systemName: alarm.mode.icon)
                .font(.system(size: 14))
                .foregroundColor(alarm.isEnabled ? .accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(alarm.formattedTime)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(alarm.isEnabled ? .primary : .secondary)

                    Text(alarm.repeatOption.rawValue)
                        .font(.system(size: 10, weight: .medium))
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

    // MARK: - Add / Edit Alarm Sheet

    private var addAlarmSheetView: some View {
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

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack {
            // Settings button
            Button(action: {
                vm.showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $vm.showingSettings) {
                settingsPopover
            }

            // Rescan button
            Button(action: {
                wiz.rescanNetwork()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text(wiz.isScanning ? "Scanning..." : "Rescan IP")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(wiz.isScanning)

            Spacer()

            // Quit App button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bulb Settings")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Bulb IP Address:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("192.168.0.5", text: $vm.customIP)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button("Save") {
                        wiz.ipAddress = vm.customIP
                        vm.showingSettings = false
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            Text("Local Security Note:")
                .font(.system(size: 11, weight: .medium))
            Text("In the WiZ App > Settings > Security, ensure 'Allow all controls' is selected for instant UDP control.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 240)
    }
}

// VisualEffectView for sleek native macOS vibrancy
public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    public func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
