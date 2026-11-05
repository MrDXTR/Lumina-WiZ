import Foundation

/// Centralized repository for all UserDefaults keys used by Lumina.
public enum DefaultsKey {
    public static let bulbIP = "WizBulbIP"
    public static let bulbLabel = "WizBulbLabel"
    public static let dynamicSpeed = "WizDynamicSpeed"
    public static let favoriteColors = "LuminaFavoriteColors"
    public static let alarms = "LuminaSavedAlarms"
    public static let defaultBrightness = "WizDefaultBrightness"
    public static let defaultTemperature = "WizDefaultTemperature"
    public static let savedPresets = "LuminaSavedPresets"
}

/// Defaults registrar establishing reliable initial values across the app.
public enum Defaults {
    public static let defaultIP = "192.168.0.5"
    public static let defaultLabel = "Philips WiZ Neo"
    public static let defaultSpeed: Double = 100.0
    public static let defaultBrightness: Double = 100.0
    public static let defaultTemperature: Double = 3500.0
    public static let defaultFavorites: [String] = [
        "#FFB347", // Warm Peach
        "#FF477E", // Neon Coral
        "#8B5CF6", // Electric Violet
        "#00B4D8", // Cyan Wave
        "#10B981"  // Emerald Glow
    ]

    public static let defaultSavedPresets: [SavedPreset] = [
        SavedPreset(
            name: "Cozy Evening",
            brightness: 45.0,
            colorHex: "#FFB347",
            temperature: 2700.0,
            mode: .temperature
        ),
        SavedPreset(
            name: "Daylight Focus",
            brightness: 100.0,
            colorHex: "#FFF9E6",
            temperature: 5500.0,
            mode: .temperature
        ),
        SavedPreset(
            name: "Cyber Neon",
            brightness: 85.0,
            colorHex: "#8B5CF6",
            temperature: nil,
            mode: .color
        ),
        SavedPreset(
            name: "Night Light",
            brightness: 15.0,
            colorHex: "#FF7700",
            temperature: 2200.0,
            mode: .temperature
        )
    ]

    public static func register() {
        UserDefaults.standard.register(defaults: [
            DefaultsKey.bulbIP: defaultIP,
            DefaultsKey.bulbLabel: defaultLabel,
            DefaultsKey.dynamicSpeed: defaultSpeed,
            DefaultsKey.defaultBrightness: defaultBrightness,
            DefaultsKey.defaultTemperature: defaultTemperature,
            DefaultsKey.favoriteColors: defaultFavorites
        ])
    }
}
