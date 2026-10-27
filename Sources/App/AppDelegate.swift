import AppKit
import SwiftUI
import Combine

public final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusController: StatusItemController!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    private var globalDismissMonitor: Any?
    private var localKeyMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default values
        Defaults.register()

        // Initialize status bar controller
        statusController = StatusItemController()
        statusController.onLeftClick = { [weak self] in
            self?.togglePopover()
        }
        statusController.onRightClick = {
            WizService.shared.togglePower()
        }

        // Initialize ScheduleManager
        _ = ScheduleManager.shared

        // Setup Popover with .applicationDefined behavior to prevent accidental closes on sheet interactions
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 515)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MainView())
        self.popover = popover

        // Bind publishers to update status icon
        WizService.shared.$isOn
            .combineLatest(WizService.shared.$color, WizService.shared.$brightness, ScheduleManager.shared.$isAlarmTriggered)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn, color, brightness, isAlarm in
                self?.statusController.updateIcon(
                    isOn: isOn,
                    color: color,
                    brightness: brightness,
                    isAlarmTriggered: isAlarm
                )

                if isAlarm, let self = self, !self.popover.isShown, let button = self.statusController.button {
                    self.showPopover(anchor: button)
                }
            }
            .store(in: &cancellables)

        // Install event monitors to dismiss .applicationDefined popover when clicking outside
        installDismissMonitors()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        removeDismissMonitors()
    }

    // MARK: - Popover Presentation & Outside Click Handling

    private func togglePopover() {
        guard let button = statusController.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            showPopover(anchor: button)
        }
    }

    private func showPopover(anchor: NSStatusBarButton) {
        WizService.shared.refreshStatus()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        // Global monitor for clicks outside the application window
        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            let mouseLocation = NSEvent.mouseLocation
            // If the click is on the status item itself, let the button handler toggle it
            guard !self.statusController.contains(point: mouseLocation) else { return }
            self.closePopover()
        }

        // Local monitor for Escape key
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.popover.isShown else { return event }
            if event.keyCode == 53 { // ESC key
                self.closePopover()
                return nil
            }
            return event
        }
    }

    private func removeDismissMonitors() {
        if let monitor = globalDismissMonitor {
            NSEvent.removeMonitor(monitor)
            globalDismissMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}
