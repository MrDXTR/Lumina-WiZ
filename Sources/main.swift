import AppKit

// Headless verification flag
if CommandLine.arguments.contains("--selftest") {
    SelfTest.runAndExit()
}

// Normal GUI Application Launch
Defaults.register()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
