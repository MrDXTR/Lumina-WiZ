import Foundation
import AppKit
import Combine

public enum AlarmMode: String, CaseIterable, Identifiable, Codable {
    case hardwareAlarm = "WiZ Alarm Effect"
    case customPulse = "Flashing Strobe"
    case designatedColor = "Designated Color"
    case turnOff = "Turn Off"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .hardwareAlarm: return "bell.badge.fill"
        case .customPulse: return "waveform.path"
        case .designatedColor: return "sun.max.fill"
        case .turnOff: return "moon.fill"
        }
    }

    public var summary: String {
        switch self {
        case .hardwareAlarm: return "WiZ bulb native alarm scene (firmware-driven)"
        case .customPulse: return "Rapid ON/OFF blinking at full brightness"
        case .designatedColor: return "Turn on to designated color & brightness"
        case .turnOff: return "Turn bulb off"
        }
    }
}

public enum AlarmRepeat: String, CaseIterable, Identifiable, Codable {
    case once = "Once"
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekends = "Weekends"

    public var id: String { rawValue }
}

public struct BulbAlarm: Identifiable, Codable, Equatable {
    public var id: UUID
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int
    public var repeatOption: AlarmRepeat
    public var mode: AlarmMode
    public var designatedColorHex: String
    public var designatedBrightness: Double
    public var durationSeconds: Int

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        hour: Int = 9,
        minute: Int = 0,
        repeatOption: AlarmRepeat = .daily,
        mode: AlarmMode = .hardwareAlarm,
        designatedColorHex: String = "#FF9F43",
        designatedBrightness: Double = 100.0,
        durationSeconds: Int = 30
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.repeatOption = repeatOption
        self.mode = mode
        self.designatedColorHex = designatedColorHex
        self.designatedBrightness = designatedBrightness
        self.durationSeconds = durationSeconds
    }

    public var formattedTime: String {
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

    private let userDefaultsKey = "LuminaSavedAlarms"

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
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
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
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
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
            if alarm.hour == currentHour && alarm.minute == currentMinute {
                var shouldTrigger = false
                switch alarm.repeatOption {
                case .once:
                    shouldTrigger = true
                    // Auto-disable one-time alarm after triggering
                    DispatchQueue.main.async {
                        self.alarms[index].isEnabled = false
                    }
                case .daily:
                    shouldTrigger = true
                case .weekdays:
                    shouldTrigger = (2...6).contains(currentWeekday)
                case .weekends:
                    shouldTrigger = (currentWeekday == 1 || currentWeekday == 7)
                }

                if shouldTrigger {
                    lastTriggeredTimestamp = timeKey
                    triggerAlarm(alarm)
                    break
                }
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
            WizService.shared.setSceneIdDirect(35, speed: 100)

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

        // Alternate state every 0.6s
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

private extension NSColor {
    convenience init?(hexString: String) {
        var value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xff) / 255.0,
                  green: CGFloat((rgb >> 8) & 0xff) / 255.0,
                  blue: CGFloat(rgb & 0xff) / 255.0,
                  alpha: 1.0)
    }
}
