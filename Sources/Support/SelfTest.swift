import Foundation
import AppKit

/// Headless subsystem and logic verification tool, invoked via `Lumina --selftest`.
/// Designed to run in headless environments and CI workflows without launching an AppKit GUI.
public enum SelfTest {
    public static func runAndExit() -> Never {
        print("==> Running Lumina Self-Test Suite...")
        var failures: [String] = []

        // Test 1: Defaults Registry
        Defaults.register()
        if UserDefaults.standard.string(forKey: DefaultsKey.bulbIP) == nil {
            failures.append("Defaults registry failed: bulbIP is nil")
        }

        // Test 2: UDP Payload Generation
        let pilotPayload = WizService.makePilotPayload(params: ["state": true, "dimming": 80])
        guard let method = pilotPayload["method"] as? String, method == "setPilot",
              let params = pilotPayload["params"] as? [String: Any],
              let state = params["state"] as? Bool, state == true,
              let dim = params["dimming"] as? Int, dim == 80 else {
            failures.append("WizService.makePilotPayload returned malformed dictionary")
            return exitWithFailures(failures)
        }

        let getPilotPayload = WizService.makeGetPilotPayload()
        guard let getMethod = getPilotPayload["method"] as? String, getMethod == "getPilot" else {
            failures.append("WizService.makeGetPilotPayload returned malformed method")
            return exitWithFailures(failures)
        }

        // Test 3: Color Math & Conversions
        let redColor = NSColor(hexRGB: 0xFF0000)
        guard let srgbRed = redColor.usingColorSpace(.sRGB),
              abs(srgbRed.redComponent - 1.0) < 0.01,
              abs(srgbRed.greenComponent - 0.0) < 0.01,
              abs(srgbRed.blueComponent - 0.0) < 0.01 else {
            failures.append("NSColor(hexRGB:) failed red channel precision")
            return exitWithFailures(failures)
        }

        guard let parsedHexColor = NSColor(hexString: "#10B981") else {
            failures.append("NSColor(hexString:) failed to parse #10B981")
            return exitWithFailures(failures)
        }
        _ = parsedHexColor

        let warmColor = WizService.shared.kelvinToColor(2200)
        let coolColor = WizService.shared.kelvinToColor(6500)
        guard let warmSrgb = warmColor.usingColorSpace(.sRGB),
              let coolSrgb = coolColor.usingColorSpace(.sRGB) else {
            failures.append("kelvinToColor sRGB conversion returned nil")
            return exitWithFailures(failures)
        }
        if warmSrgb.redComponent <= warmSrgb.blueComponent {
            failures.append("kelvinToColor(2200) expected red > blue for warm temperature")
        }
        if coolSrgb.blueComponent <= warmSrgb.blueComponent {
            failures.append("kelvinToColor(6500) expected blue > 2200K blue")
        }

        // Test 4: Alarm Serialization & Logic
        let testAlarm = BulbAlarm(
            id: UUID(),
            isEnabled: true,
            hour: 14,
            minute: 30,
            repeatOption: .weekdays,
            mode: .designatedColor,
            designatedColorHex: "#00B4D8",
            designatedBrightness: 75.0,
            durationSeconds: 45
        )

        do {
            let data = try JSONEncoder().encode(testAlarm)
            let decoded = try JSONDecoder().decode(BulbAlarm.self, from: data)
            if decoded.id != testAlarm.id || decoded.hour != 14 || decoded.minute != 30 || decoded.repeatOption != .weekdays {
                failures.append("BulbAlarm JSON encode/decode roundtrip mismatch")
            }
        } catch {
            failures.append("BulbAlarm JSON encoding failed: \(error)")
        }

        let mgr = ScheduleManager.shared
        // Weekday 3 is Tuesday (weekday), Weekday 1 is Sunday (weekend)
        if !mgr.shouldTriggerAlarm(alarm: testAlarm, weekday: 3, hour: 14, minute: 30) {
            failures.append("shouldTriggerAlarm failed to trigger for Tuesday weekday alarm")
        }
        if mgr.shouldTriggerAlarm(alarm: testAlarm, weekday: 1, hour: 14, minute: 30) {
            failures.append("shouldTriggerAlarm unexpectedly triggered on Sunday for weekday alarm")
        }

        exitWithFailures(failures)
    }

    private static func exitWithFailures(_ failures: [String]) -> Never {
        if failures.isEmpty {
            print("==> Self-Test Passed: 5/5 subsystems verified successfully.")
            exit(0)
        } else {
            print("==> Self-Test FAILED with \(failures.count) error(s):")
            for (idx, err) in failures.enumerated() {
                print("    [\(idx + 1)] \(err)")
            }
            exit(1)
        }
    }
}
