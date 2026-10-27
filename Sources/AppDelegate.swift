import AppKit
import SwiftUI
import Combine

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Create NSStatusItem in the system menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Philips WiZ")
            button.target = self
            button.action = #selector(handleStatusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Setup Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 530)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MainView())
        self.popover = popover

        // Observe WizService to update menu bar icon dynamically
        WizService.shared.$isOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        WizService.shared.$color
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)

        updateMenuBarIcon()
    }

    @objc private func handleStatusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        // Right click or Option-click directly toggles the bulb!
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.option) == true) {
            WizService.shared.togglePower()
            return
        }

        // Left click toggles the popover
        togglePopover(sender)
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Refresh bulb status immediately when opening
            WizService.shared.refreshStatus()

            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        let isOn = WizService.shared.isOn
        let bulbColor = WizService.shared.color

        let symbolName = isOn ? "lightbulb.fill" : "lightbulb"
        let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Philips WiZ")

        if isOn {
            // Create a tinted version of the icon with the bulb's active color
            let tinted = NSImage(size: baseImage?.size ?? NSSize(width: 18, height: 18))
            tinted.lockFocus()
            baseImage?.draw(in: NSRect(origin: .zero, size: tinted.size))
            bulbColor.set()
            NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            tinted.isTemplate = false
            button.image = tinted
            button.toolTip = "Philips WiZ: ON (\(Int(WizService.shared.brightness))%)\nOption-Click to Toggle"
        } else {
            baseImage?.isTemplate = true
            button.image = baseImage
            button.toolTip = "Philips WiZ: OFF\nOption-Click to Toggle"
        }
    }
}
