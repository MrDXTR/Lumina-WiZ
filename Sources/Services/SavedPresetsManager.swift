import Foundation
import AppKit
import Combine

public final class SavedPresetsManager: ObservableObject {
    public static let shared = SavedPresetsManager()

    @Published public var presets: [SavedPreset] = [] {
        didSet {
            savePresets()
        }
    }

    @Published public var activePresetId: UUID? = nil

    private init() {
        loadPresets()
    }

    // MARK: - Persistence

    public func loadPresets() {
        let storedData = UserDefaults.standard.data(forKey: DefaultsKey.savedPresets)
            ?? UserDefaults.standard.data(forKey: "LuminaSavedPresets")
        if let data = storedData,
           let decoded = try? JSONDecoder().decode([SavedPreset].self, from: data) {
            self.presets = decoded
        } else {
            self.presets = Defaults.defaultSavedPresets
            savePresets()
        }
    }

    public func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: DefaultsKey.savedPresets)
        }
    }

    // MARK: - Preset Management

    @discardableResult
    public func addPreset(
        name: String,
        brightness: Double,
        colorHex: String,
        temperature: Double? = nil,
        sceneId: Int? = nil,
        mode: BulbControlMode = .color
    ) -> SavedPreset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "Preset \(presets.count + 1)" : trimmed
        let preset = SavedPreset(
            name: resolvedName,
            brightness: max(10.0, min(100.0, brightness)),
            colorHex: colorHex,
            temperature: temperature,
            sceneId: sceneId,
            mode: mode
        )
        presets.insert(preset, at: 0)
        activePresetId = preset.id
        return preset
    }

    @discardableResult
    public func saveCurrentLight(wiz: WizService = .shared, name: String = "") -> SavedPreset {
        let currentBrightness = wiz.brightness
        let currentColor = wiz.color
        let currentHex = currentColor.hexString

        let modeToSave: BulbControlMode
        var tempToSave: Double? = nil
        var sceneToSave: Int? = nil

        switch wiz.lightMode {
        case .temperature:
            modeToSave = .temperature
            tempToSave = wiz.temperature
        case .scenes:
            modeToSave = .scenes
            sceneToSave = wiz.activeSceneId > 0 ? wiz.activeSceneId : nil
        case .color:
            modeToSave = .color
            tempToSave = nil
            sceneToSave = nil
        default:
            modeToSave = .color
            tempToSave = nil
            sceneToSave = nil
        }

        return addPreset(
            name: name,
            brightness: currentBrightness,
            colorHex: currentHex,
            temperature: tempToSave,
            sceneId: sceneToSave,
            mode: modeToSave
        )
    }

    public func updatePreset(_ preset: SavedPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        }
    }

    public func updatePresetWithCurrentLight(id: UUID, wiz: WizService = .shared) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        var updated = presets[index]
        updated.brightness = wiz.brightness
        updated.colorHex = wiz.color.hexString

        switch wiz.lightMode {
        case .temperature:
            updated.mode = .temperature
            updated.temperature = wiz.temperature
            updated.sceneId = nil
        case .scenes:
            updated.mode = .scenes
            updated.sceneId = wiz.activeSceneId
            updated.temperature = nil
        default:
            updated.mode = .color
            updated.temperature = nil
            updated.sceneId = nil
        }

        presets[index] = updated
        activePresetId = id
    }

    public func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        if activePresetId == id {
            activePresetId = nil
        }
    }

    public func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
    }

    public func resetToDefaults() {
        self.presets = Defaults.defaultSavedPresets
        self.activePresetId = nil
        savePresets()
    }

    public func applyPreset(_ preset: SavedPreset, wiz: WizService = .shared) {
        activePresetId = preset.id
        wiz.applyPreset(preset)
    }

    public func isPresetActive(_ preset: SavedPreset, wiz: WizService = .shared) -> Bool {
        if activePresetId == preset.id {
            return true
        }

        // Must match both the hardware lightMode and brightness
        guard wiz.lightMode == preset.mode else { return false }
        let brightnessMatches = abs(wiz.brightness - preset.brightness) < 1.0
        guard brightnessMatches else { return false }

        if preset.mode == .temperature, let temp = preset.temperature {
            return abs(wiz.temperature - temp) < 50.0
        } else if preset.mode == .scenes, let sceneId = preset.sceneId {
            return wiz.activeSceneId == sceneId
        } else {
            return wiz.color.hexString.uppercased() == preset.colorHex.uppercased()
        }
    }
}
