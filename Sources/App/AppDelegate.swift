import AppKit
import SwiftUI
import Combine

public final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusController = StatusItemController()
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default values into UserDefaults
        Defaults.register()

        // Setup status item controller
        statusController.onLeftClick = { [weak self] in
            self?.togglePopover()
        }
        statusController.onRightClick = {
            WizService.shared.togglePower()
        }

        // Initialize background schedule evaluator
        _ = ScheduleManager.shared

        // Setup Popover
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
            }
            .store(in: &cancellables)

        // Show popover strictly when an alarm transitions to triggered (rising edge)
        ScheduleManager.shared.$isAlarmTriggered
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.popover.isShown,
                      let button = self.statusController.button else { return }
                self.showPopover(anchor: button)
            }
            .store(in: &cancellables)

        // Install event monitor to dismiss popover when clicking outside the application
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
        if popover.isShown {
            popover.performClose(nil)
            MainViewModel.shared.showingAlarmSheet = false
            MainViewModel.shared.showingSettings = false
        }
    }

    private func installDismissMonitors() {
        // Global monitor catches clicks outside the application windows
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func removeDismissMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
