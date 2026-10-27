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
}
