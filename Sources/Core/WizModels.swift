import Foundation
import AppKit

// MARK: - Color Utilities

public extension NSColor {
    convenience init(hexRGB: UInt32) {
        self.init(srgbRed: CGFloat((hexRGB >> 16) & 0xff) / 255.0,
                  green: CGFloat((hexRGB >> 8) & 0xff) / 255.0,
                  blue: CGFloat(hexRGB & 0xff) / 255.0, alpha: 1.0)
    }

    convenience init?(hexString: String) {
        var clean = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        guard clean.count == 6, let rgb = UInt32(clean, radix: 16) else {
            return nil
        }
        self.init(hexRGB: rgb)
    }

    convenience init?(hex: String) {
        self.init(hexString: hex)
    }

    var hexString: String {
        guard let srgb = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(round(srgb.redComponent * 255))
        let g = Int(round(srgb.greenComponent * 255))
        let b = Int(round(srgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Bulb Control Mode

public enum BulbControlMode: String, CaseIterable, Identifiable, Codable {
    case color = "Color"
    case temperature = "White"
    case scenes = "Scenes"
    case alarms = "Alarm"

    public var id: String { rawValue }
}

// MARK: - WiZ Scene Model

public struct WizScene: Identifiable, Equatable, Hashable {
    public let id: Int
    public let name: String
    public let icon: String
    public let isDynamic: Bool
    public let previewColor: NSColor

    public init(id: Int, name: String, icon: String, isDynamic: Bool = true, previewColor: NSColor = .white) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isDynamic = isDynamic
        self.previewColor = previewColor
    }
}

// MARK: - Alarm & Schedule Models

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

    public var timeFormatted: String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
