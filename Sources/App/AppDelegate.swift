import AppKit
import SwiftUI
import Combine

public final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusController = StatusItemController()
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default values into UserDefaults
        Defaults.register()

        // Setup standard application edit menu for keyboard shortcuts
        setupMainMenu()

        // Setup local key monitor for standard editing shortcuts (Cmd+A, Cmd+C, etc.)
        setupKeyEquivalentMonitor()

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
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Application Menu & Key Equivalents Setup

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupKeyEquivalentMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command) else {
                return event
            }

            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }

            switch chars {
            case "a":
                if self?.performEditAction(#selector(NSText.selectAll(_:))) == true {
                    return nil
                }
            case "c":
                if self?.performEditAction(#selector(NSText.copy(_:))) == true {
                    return nil
                }
            case "v":
                if self?.performEditAction(#selector(NSText.paste(_:))) == true {
                    return nil
                }
            case "x":
                if self?.performEditAction(#selector(NSText.cut(_:))) == true {
                    return nil
                }
            case "z":
                let isShift = event.modifierFlags.contains(.shift)
                let action = isShift ? Selector(("redo:")) : Selector(("undo:"))
                if self?.performEditAction(action) == true {
                    return nil
                }
            default:
                break
            }

            return event
        }
    }

    private func performEditAction(_ selector: Selector) -> Bool {
        if NSApp.sendAction(selector, to: nil, from: nil) {
            return true
        }
        if let firstResponder = NSApp.keyWindow?.firstResponder,
           firstResponder.tryToPerform(selector, with: nil) {
            return true
        }
        return false
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
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            window.makeKeyAndOrderFront(nil)
        }
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
