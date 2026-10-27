import SwiftUI
import Combine
import AppKit

public final class ColorWheelViewModel: ObservableObject {
    @Published public var knobPosition: CGPoint = .zero
    @Published public var isDragging: Bool = false
    @Published public var hexText: String = ""
    @Published public var favoriteColors: [String] = []

    private let favoritesKey = "LuminaFavoriteColors"

    public init() {
        loadFavorites()
    }

    public func loadFavorites() {
        if let saved = UserDefaults.standard.stringArray(forKey: favoritesKey), !saved.isEmpty {
            self.favoriteColors = Array(saved.prefix(5))
        } else {
            // 5 elegant initial defaults
            self.favoriteColors = [
                "#FFB347", // Warm Peach
                "#FF477E", // Neon Coral
                "#8B5CF6", // Electric Violet
                "#00B4D8", // Cyan Wave
                "#10B981"  // Emerald Glow
            ]
            saveFavorites()
        }
    }

    public func saveFavorites() {
        UserDefaults.standard.set(favoriteColors, forKey: favoritesKey)
    }

    public func addCurrentColorAsFavorite(_ hex: String) {
        let normalized = hex.uppercased()
        if !favoriteColors.contains(normalized) && favoriteColors.count < 5 {
            favoriteColors.append(normalized)
            saveFavorites()
        }
    }

    public func removeFavorite(at index: Int) {
        guard index >= 0 && index < favoriteColors.count else { return }
        favoriteColors.remove(at: index)
        saveFavorites()
    }

    public func replaceFavorite(at index: Int, with hex: String) {
        guard index >= 0 && index < favoriteColors.count else { return }
        favoriteColors[index] = hex.uppercased()
        saveFavorites()
    }
}

public final class MainViewModel: ObservableObject {
    @Published public var showingSettings: Bool = false
    @Published public var showingAlarmSheet: Bool = false
    @Published public var customIP: String = ""
    @Published public var tempInputText: String = ""
    @Published public var isDraggingTemp: Bool = false

    // Alarm Sheet State
    @Published public var editingAlarmId: UUID? = nil
    @Published public var newAlarmTime: Date = Date()
    @Published public var newAlarmRepeat: AlarmRepeat = .daily
    @Published public var newAlarmMode: AlarmMode = .hardwareAlarm
    @Published public var newAlarmBrightness: Double = 100.0

    public init() {
        self.customIP = WizService.shared.ipAddress
        self.tempInputText = "\(Int(WizService.shared.temperature))"
    }

    public func syncTemperature(_ kelvin: Double) {
        let rounded = Int(kelvin)
        let text = "\(rounded)"
        if tempInputText != text {
            tempInputText = text
        }
    }

    public func startNewAlarm() {
        editingAlarmId = nil
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        newAlarmTime = Calendar.current.date(from: comps) ?? Date()
        newAlarmRepeat = .daily
        newAlarmMode = .hardwareAlarm
        newAlarmBrightness = 100.0
        showingAlarmSheet = true
    }

    public func startEditingAlarm(_ alarm: BulbAlarm) {
        editingAlarmId = alarm.id
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = alarm.hour
        comps.minute = alarm.minute
        newAlarmTime = Calendar.current.date(from: comps) ?? Date()
        newAlarmRepeat = alarm.repeatOption
        newAlarmMode = alarm.mode
        newAlarmBrightness = alarm.designatedBrightness
        showingAlarmSheet = true
    }
}
