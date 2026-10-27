import AppKit
import Combine

/// Manages the system menu bar item presence, click routing, and cached icon rendering.
public final class StatusItemController: NSObject {
    public var onLeftClick: (() -> Void)?
    public var onRightClick: (() -> Void)?

    private(set) var statusItem: NSStatusItem!
    private var lastRenderKey: String = ""

    public override init() {
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        // Right-click or Option-click triggers quick power toggle
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.option) == true) {
            onRightClick?()
            return
        }

        // Left-click toggles popover
        onLeftClick?()
    }

    public func contains(point: NSPoint) -> Bool {
        guard let button = statusItem.button, let window = button.window else { return false }
        let windowPoint = window.convertPoint(fromScreen: point)
        return button.bounds.contains(button.convert(windowPoint, from: nil))
    }

    public var buttonBounds: NSRect? {
        statusItem.button?.bounds
    }

    public var button: NSStatusBarButton? {
        statusItem.button
    }

    /// Renders the menu bar icon, skipping redraw if state has not visibly changed.
    public func updateIcon(isOn: Bool, color: NSColor, brightness: Double, isAlarmTriggered: Bool) {
        guard let button = statusItem.button else { return }

        let currentKey = "\(isAlarmTriggered)-\(isOn)-\(color.hexString)-\(Int(brightness))"
        guard currentKey != lastRenderKey else { return }
        lastRenderKey = currentKey

        if isAlarmTriggered {
            let alarmImage = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "Alarm Active")
            alarmImage?.isTemplate = true
            button.image = alarmImage
            button.toolTip = "Philips WiZ: ALARM RINGING! Click to Dismiss"
            return
        }

        let symbolName = isOn ? "lightbulb.fill" : "lightbulb"
        let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Philips WiZ")

        if isOn {
            let iconSize = baseImage?.size ?? NSSize(width: 18, height: 18)
            let tinted = NSImage(size: iconSize)
            tinted.lockFocus()
            baseImage?.draw(in: NSRect(origin: .zero, size: iconSize))
            color.set()
            NSRect(origin: .zero, size: iconSize).fill(using: .sourceAtop)
            tinted.unlockFocus()
            tinted.isTemplate = false
            button.image = tinted
            button.toolTip = "Philips WiZ: ON (\(Int(brightness))%) • Option-Click to Toggle"
        } else {
            baseImage?.isTemplate = true
            button.image = baseImage
            button.toolTip = "Philips WiZ: OFF • Option-Click to Toggle"
        }
    }
}
