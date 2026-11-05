import Foundation
import AppKit

public enum LuminaTests {
    private static var totalTests = 0
    private static var passedTests = 0
    private static var failedTests = 0

    public static func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) {
        totalTests += 1
        if a == b {
            passedTests += 1
        } else {
            failedTests += 1
            print("  ❌ [FAIL] \(file):\(line): Expected '\(b)', got '\(a)' - \(message)")
        }
    }

    public static func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        totalTests += 1
        if condition {
            passedTests += 1
        } else {
            failedTests += 1
            print("  ❌ [FAIL] \(file):\(line): Expected true, got false - \(message)")
        }
    }

    public static func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        assertTrue(!condition, message, file: file, line: line)
    }

    public static func runAll() -> Bool {
        print("==> Executing Lumina Test Suite...")
        totalTests = 0
        passedTests = 0
        failedTests = 0

        Defaults.register()

        testDefaultsRegistration()
        testMakePilotPayload()
        testMakeGetPilotPayload()
        testColorHexParsingAndFormatting()
        testKelvinToColorWarmth()
        testAlarmScheduleTriggering()
        testBulbAlarmCodable()
        testAlarmAddAndEditWorkflow()
        testSavedPresetCodable()
        testSavedPresetsManagerAddAndApply()
        testMakePresetPayload()

        print("==> Test Results: \(passedTests)/\(totalTests) passed (\(failedTests) failed).")
        return failedTests == 0
    }

    private static func testDefaultsRegistration() {
        let ip = UserDefaults.standard.string(forKey: DefaultsKey.bulbIP)
        assertTrue(ip != nil, "Bulb IP should be registered")
        assertEqual(Defaults.defaultIP, "192.168.0.5", "Default IP match")
    }

    private static func testMakePilotPayload() {
        let payload = WizService.makePilotPayload(params: [
            "state": true,
            "dimming": 85,
            "temp": 4000
        ])
        assertEqual(payload["method"] as? String, "setPilot", "Method matches setPilot")
        assertEqual(payload["env"] as? String, "pro", "Env matches pro")

        guard let params = payload["params"] as? [String: Any] else {
            assertTrue(false, "Params must exist")
            return
        }
        assertEqual(params["state"] as? Bool, true, "State must be true")
        assertEqual(params["dimming"] as? Int, 85, "Dimming must be 85")
        assertEqual(params["temp"] as? Int, 4000, "Temp must be 4000")
    }

    private static func testMakeGetPilotPayload() {
        let payload = WizService.makeGetPilotPayload()
        assertEqual(payload["method"] as? String, "getPilot", "Method matches getPilot")
        assertEqual(payload["env"] as? String, "pro", "Env matches pro")
    }

    private static func testColorHexParsingAndFormatting() {
        let color = NSColor(hexString: "#FF477E")
        assertTrue(color != nil, "Color should parse from #FF477E")
        assertEqual(color?.hexString, "#FF477E", "Hex string roundtrip")

        let cyan = NSColor(hexRGB: 0x00B4D8)
        assertEqual(cyan.hexString, "#00B4D8", "RGB hex string formatting")
    }

    private static func testKelvinToColorWarmth() {
        let warm = WizService.shared.kelvinToColor(2200)
        let cool = WizService.shared.kelvinToColor(6500)

        guard let warmRgb = warm.usingColorSpace(.sRGB),
              let coolRgb = cool.usingColorSpace(.sRGB) else {
            assertTrue(false, "Failed to get sRGB colors")
            return
        }

        assertTrue(warmRgb.redComponent > warmRgb.blueComponent, "Warm 2200K has red > blue")
        assertTrue(coolRgb.blueComponent > warmRgb.blueComponent, "Cool 6500K has more blue than 2200K")
    }

    private static func testAlarmScheduleTriggering() {
        let mgr = ScheduleManager.shared
        let weekdayAlarm = BulbAlarm(
            hour: 8,
            minute: 30,
            repeatOption: .weekdays,
            mode: .hardwareAlarm
        )

        // Monday (2) -> Should trigger
        assertTrue(mgr.shouldTriggerAlarm(alarm: weekdayAlarm, weekday: 2, hour: 8, minute: 30), "Triggers on Monday")
        // Sunday (1) -> Should not trigger
        assertFalse(mgr.shouldTriggerAlarm(alarm: weekdayAlarm, weekday: 1, hour: 8, minute: 30), "Does not trigger on Sunday")
        // Wrong hour -> Should not trigger
        assertFalse(mgr.shouldTriggerAlarm(alarm: weekdayAlarm, weekday: 2, hour: 9, minute: 0), "Does not trigger at wrong hour")

        let weekendAlarm = BulbAlarm(
            hour: 10,
            minute: 0,
            repeatOption: .weekends,
            mode: .customPulse
        )
        // Saturday (7) -> Should trigger
        assertTrue(mgr.shouldTriggerAlarm(alarm: weekendAlarm, weekday: 7, hour: 10, minute: 0), "Triggers on Saturday")
        // Wednesday (4) -> Should not trigger
        assertFalse(mgr.shouldTriggerAlarm(alarm: weekendAlarm, weekday: 4, hour: 10, minute: 0), "Does not trigger on Wednesday")
    }

    private static func testBulbAlarmCodable() {
        let original = BulbAlarm(
            id: UUID(),
            isEnabled: true,
            hour: 7,
            minute: 45,
            repeatOption: .daily,
            mode: .designatedColor,
            designatedColorHex: "#8B5CF6",
            designatedBrightness: 60.0,
            durationSeconds: 20
        )

        do {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(BulbAlarm.self, from: data)

            assertEqual(original.id, decoded.id, "ID matches")
            assertEqual(original.hour, decoded.hour, "Hour matches")
            assertEqual(original.minute, decoded.minute, "Minute matches")
            assertEqual(original.repeatOption, decoded.repeatOption, "Repeat matches")
            assertEqual(original.mode, decoded.mode, "Mode matches")
            assertEqual(original.designatedColorHex, decoded.designatedColorHex, "Color hex matches")
            assertEqual(original.designatedBrightness, decoded.designatedBrightness, "Brightness matches")
            assertEqual(original.durationSeconds, decoded.durationSeconds, "Duration matches")
        } catch {
            assertTrue(false, "Encoding error: \(error)")
        }
    }

    private static func testAlarmAddAndEditWorkflow() {
        let mgr = ScheduleManager.shared
        let initialCount = mgr.alarms.count

        let testId = UUID()
        let newAlarm = BulbAlarm(
            id: testId,
            isEnabled: true,
            hour: 14,
            minute: 15,
            repeatOption: .weekdays,
            mode: .hardwareAlarm,
            designatedBrightness: 80.0,
            durationSeconds: 30
        )
        mgr.updateAlarm(newAlarm)
        assertEqual(mgr.alarms.count, initialCount + 1, "Alarm count increments on new add")

        // Edit the alarm
        var editedAlarm = newAlarm
        editedAlarm.hour = 15
        editedAlarm.minute = 30
        editedAlarm.designatedBrightness = 50.0
        mgr.updateAlarm(editedAlarm)

        assertEqual(mgr.alarms.count, initialCount + 1, "Alarm count unchanged on edit")
        let found = mgr.alarms.first(where: { $0.id == testId })
        assertEqual(found?.hour, 15, "Edited hour matches")
        assertEqual(found?.minute, 30, "Edited minute matches")
        assertEqual(found?.designatedBrightness, 50.0, "Edited brightness matches")

        // Clean up
        mgr.deleteAlarm(id: testId)
        assertEqual(mgr.alarms.count, initialCount, "Alarm cleaned up successfully")
    }

    private static func testSavedPresetCodable() {
        let preset = SavedPreset(
            id: UUID(),
            name: "Sunset Relax",
            brightness: 65.0,
            colorHex: "#FF5E62",
            temperature: 2800.0,
            sceneId: nil,
            mode: .temperature
        )

        do {
            let data = try JSONEncoder().encode(preset)
            let decoded = try JSONDecoder().decode(SavedPreset.self, from: data)

            assertEqual(preset.id, decoded.id, "Preset ID matches")
            assertEqual(preset.name, decoded.name, "Preset name matches")
            assertEqual(preset.brightness, decoded.brightness, "Preset brightness matches")
            assertEqual(preset.colorHex, decoded.colorHex, "Preset colorHex matches")
            assertEqual(preset.temperature, decoded.temperature, "Preset temperature matches")
            assertEqual(preset.mode, decoded.mode, "Preset mode matches")
        } catch {
            assertTrue(false, "SavedPreset encoding error: \(error)")
        }
    }

    private static func testSavedPresetsManagerAddAndApply() {
        let mgr = SavedPresetsManager.shared
        let initialCount = mgr.presets.count

        let newPreset = mgr.addPreset(
            name: "Testing Glow",
            brightness: 80.0,
            colorHex: "#00B4D8",
            mode: .color
        )
        assertEqual(mgr.presets.count, initialCount + 1, "Preset count increments on add")
        assertEqual(mgr.presets.first?.name, "Testing Glow", "Newly added preset is at top")
        assertEqual(mgr.activePresetId, newPreset.id, "Newly added preset becomes active")

        // Edit/update preset
        var edited = newPreset
        edited.name = "Renamed Glow"
        edited.brightness = 90.0
        mgr.updatePreset(edited)

        let found = mgr.presets.first(where: { $0.id == newPreset.id })
        assertEqual(found?.name, "Renamed Glow", "Preset renamed")
        assertEqual(found?.brightness, 90.0, "Preset brightness updated")

        // Clean up
        mgr.deletePreset(id: newPreset.id)
        assertEqual(mgr.presets.count, initialCount, "Preset count restored after delete")

        // Test saving color when on Saved tab
        let wiz = WizService.shared
        let redColor = NSColor(hexString: "#FF0000")!
        wiz.setColor(redColor)
        wiz.setBrightness(27.0)
        assertEqual(wiz.lightMode, .color, "Light mode is color after setColor")

        // User navigates to Saved tab
        wiz.selectMode(.saved)
        assertEqual(wiz.activeMode, .saved, "Active mode is now saved tab")
        assertEqual(wiz.lightMode, .color, "Light mode remains color after tab switch")

        let redPreset = mgr.saveCurrentLight(wiz: wiz, name: "Red")
        assertEqual(redPreset.name, "Red", "Preset name is Red")
        assertEqual(redPreset.mode, .color, "Preset mode is color, NOT temperature")
        assertEqual(redPreset.colorHex, "#FF0000", "Preset colorHex is #FF0000")
        assertTrue(redPreset.temperature == nil, "Preset temperature is nil")
        assertEqual(redPreset.brightness, 27.0, "Preset brightness is 27%")
        assertTrue(redPreset.displaySubtitle.contains("#FF0000"), "Subtitle contains hex code")
        assertFalse(redPreset.displaySubtitle.contains("2700K"), "Subtitle does NOT contain 2700K")

        // Clean up
        mgr.deletePreset(id: redPreset.id)
    }

    private static func testMakePresetPayload() {
        // Temperature Preset
        let tempPreset = SavedPreset(
            name: "Warm Study",
            brightness: 75.0,
            colorHex: "#FFB347",
            temperature: 3200.0,
            mode: .temperature
        )
        let tempPayload = WizService.makePresetPayload(preset: tempPreset)
        assertEqual(tempPayload["method"] as? String, "setPilot", "Method is setPilot")
        guard let tempParams = tempPayload["params"] as? [String: Any] else {
            assertTrue(false, "Params must exist")
            return
        }
        assertEqual(tempParams["state"] as? Bool, true, "State is true")
        assertEqual(tempParams["dimming"] as? Int, 75, "Dimming is 75")
        assertEqual(tempParams["temp"] as? Int, 3200, "Temp is 3200")

        // Color Preset
        let colorPreset = SavedPreset(
            name: "Cyan Chill",
            brightness: 50.0,
            colorHex: "#00B4D8",
            mode: .color
        )
        let colorPayload = WizService.makePresetPayload(preset: colorPreset)
        guard let colorParams = colorPayload["params"] as? [String: Any] else {
            assertTrue(false, "Color params must exist")
            return
        }
        assertEqual(colorParams["state"] as? Bool, true, "State is true")
        assertEqual(colorParams["dimming"] as? Int, 50, "Dimming is 50")
        assertEqual(colorParams["r"] as? Int, 0, "R channel is 0")
        assertEqual(colorParams["g"] as? Int, 180, "G channel is 180")
        assertEqual(colorParams["b"] as? Int, 216, "B channel is 216")
    }
}
