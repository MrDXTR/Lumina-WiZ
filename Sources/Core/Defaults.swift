import Foundation

/// Centralized repository for all UserDefaults keys used by Lumina.
public enum DefaultsKey {
    public static let bulbIP = "WizBulbIP"
    public static let bulbLabel = "WizBulbLabel"
    public static let dynamicSpeed = "WizDynamicSpeed"
    public static let favoriteColors = "LuminaFavoriteColors"
    public static let alarms = "LuminaBulbAlarms"
    public static let defaultBrightness = "WizDefaultBrightness"
    public static let defaultTemperature = "WizDefaultTemperature"
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
