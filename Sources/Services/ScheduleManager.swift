import Foundation
import AppKit
import Combine

public extension BulbAlarm {
    var formattedTime: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", h, minute, ampm)
    }
}

public final class ScheduleManager: ObservableObject {
    public static let shared = ScheduleManager()

    @Published public var alarms: [BulbAlarm] = [] {
        didSet {
            saveAlarms()
        }
    }

    @Published public var isAlarmTriggered: Bool = false
    @Published public var activeAlarmDescription: String? = nil

    private var checkTimer: Timer?
    private var customFlashTimer: Timer?
    private var alarmDurationTimer: Timer?
    private var lastTriggeredTimestamp: String = ""
    private var flashToggleState: Bool = false

    private init() {
        loadAlarms()
        startMonitoring()
    }

    deinit {
        checkTimer?.invalidate()
        customFlashTimer?.invalidate()
        alarmDurationTimer?.invalidate()
    }

    // MARK: - Alarm Persistence

    private func loadAlarms() {
        let storedData = UserDefaults.standard.data(forKey: DefaultsKey.alarms)
            ?? UserDefaults.standard.data(forKey: "LuminaBulbAlarms")
        if let data = storedData,
           let decoded = try? JSONDecoder().decode([BulbAlarm].self, from: data) {
            self.alarms = decoded
        } else {
            // Default 9:00 AM alarm with 30s duration
            self.alarms = [
                BulbAlarm(
                    hour: 9,
                    minute: 0,
                    repeatOption: .daily,
                    mode: .hardwareAlarm,
                    designatedColorHex: "#FFB300",
                    designatedBrightness: 100.0,
                    durationSeconds: 30
                )
            ]
        }
    }

    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: DefaultsKey.alarms)
        }
    }

    public func addAlarm(_ alarm: BulbAlarm) {
        alarms.append(alarm)
    }

    public func updateAlarm(_ alarm: BulbAlarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
    }

    public func deleteAlarm(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
    }

    public func deleteAlarm(id: UUID) {
        alarms.removeAll { $0.id == id }
    }

    // MARK: - Schedule Engine

    private func startMonitoring() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
            self?.evaluateAlarms()
        }
    }

    public func shouldTriggerAlarm(alarm: BulbAlarm, weekday: Int, hour: Int, minute: Int) -> Bool {
        guard alarm.isEnabled && alarm.hour == hour && alarm.minute == minute else { return false }
        switch alarm.repeatOption {
        case .once, .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekends:
            return (weekday == 1 || weekday == 7)
        }
    }

    private func evaluateAlarms() {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        guard let currentWeekday = comps.weekday,
              let currentHour = comps.hour,
              let currentMinute = comps.minute else { return }

        let timeKey = "\(currentWeekday)-\(currentHour):\(currentMinute)"
        guard timeKey != lastTriggeredTimestamp else { return }

        for (index, alarm) in alarms.enumerated() where alarm.isEnabled {
            if shouldTriggerAlarm(alarm: alarm, weekday: currentWeekday, hour: currentHour, minute: currentMinute) {
                if alarm.repeatOption == .once {
                    DispatchQueue.main.async {
                        self.alarms[index].isEnabled = false
                    }
                }

                lastTriggeredTimestamp = timeKey
                triggerAlarm(alarm)
                break
            }
        }
    }

    public func triggerAlarm(_ alarm: BulbAlarm) {
        DispatchQueue.main.async {
            self.isAlarmTriggered = true
            self.activeAlarmDescription = "Alarm (\(alarm.formattedTime)) - \(alarm.mode.rawValue)"
        }

        switch alarm.mode {
        case .hardwareAlarm:
            // Scene 35 is WiZ native Alarm scene; runs firmware-level pulsing
            WizService.shared.setBrightness(alarm.designatedBrightness)
            WizService.shared.setSceneIdDirect(35, speed: 100, brightness: alarm.designatedBrightness)

        case .customPulse:
            // Rapid flashing loop for 30s
            startCustomFlashLoop(colorHex: alarm.designatedColorHex, brightness: alarm.designatedBrightness)

        case .designatedColor:
            WizService.shared.setPower(true)
            WizService.shared.setBrightness(alarm.designatedBrightness)
            if let color = NSColor(hexString: alarm.designatedColorHex) {
                WizService.shared.setColor(color)
            }

        case .turnOff:
            WizService.shared.setPower(false)
        }

        // Auto-stop alarm after durationSeconds (defaults to 30s)
        alarmDurationTimer?.invalidate()
        let duration = max(5, alarm.durationSeconds > 0 ? alarm.durationSeconds : 30)
        alarmDurationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration), repeats: false) { [weak self] _ in
            self?.dismissAlarm()
        }
    }

    public func dismissAlarm() {
        customFlashTimer?.invalidate()
        customFlashTimer = nil
        alarmDurationTimer?.invalidate()
        alarmDurationTimer = nil

        DispatchQueue.main.async {
            self.isAlarmTriggered = false
            self.activeAlarmDescription = nil
        }

        // Actively stop the WiZ alarm scene or flashing loop and reset to steady warm light
        WizService.shared.activeSceneId = 0
        WizService.shared.setTemperature(3000)
    }

    private func startCustomFlashLoop(colorHex: String, brightness: Double) {
        customFlashTimer?.invalidate()
        flashToggleState = true
        let targetColor = NSColor(hexString: colorHex) ?? NSColor.white

        // Immediately turn on at target color & brightness
        WizService.shared.setBrightness(brightness)
        WizService.shared.setColor(targetColor)

        // Alternate state every 0.65s
        customFlashTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.flashToggleState.toggle()
            if self.flashToggleState {
                WizService.shared.setColor(targetColor)
                WizService.shared.setBrightness(brightness)
            } else {
                WizService.shared.setPower(false)
            }
        }
    }
}
