import Foundation
import AppKit
import Combine

public final class WizService: ObservableObject {
    public static let shared = WizService()

    @Published public var ipAddress: String {
        didSet {
            UserDefaults.standard.set(ipAddress, forKey: DefaultsKey.bulbIP)
            refreshStatus()
        }
    }

    @Published public var isOn: Bool = false
    @Published public var brightness: Double = 100.0 // 10 to 100
    @Published public var color: NSColor = NSColor(srgbRed: 1.0, green: 0.85, blue: 0.65, alpha: 1.0)
    @Published public var temperature: Double = 3500.0 // 2200 to 6500 Kelvin
    @Published public var dynamicSpeed: Double = 100.0 // 20 to 100
    @Published public var activeMode: BulbControlMode = .temperature
    @Published public var activeSceneId: Int = 0
    @Published public var visualChangeToken: UInt = 0
    @Published public var isConnected: Bool = false
    @Published public var isScanning: Bool = false
    @Published public var lastErrorMessage: String? = nil

    public let availableScenes: [WizScene] = [
        // Native Hardware Dynamic Lighting (executed on bulb firmware)
        WizScene(id: 33, name: "Diwali", icon: "sparkler", isDynamic: true, previewColor: NSColor(hexRGB: 0xFF9F1C)),
        WizScene(id: 1, name: "Ocean", icon: "water.waves", isDynamic: true, previewColor: NSColor(hexRGB: 0x00B4D8)),
        WizScene(id: 3, name: "Sunset", icon: "sunset.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0xFF5E62)),
        WizScene(id: 4, name: "Party", icon: "sparkles", isDynamic: true, previewColor: NSColor(hexRGB: 0xE040FB)),
        WizScene(id: 5, name: "Fireplace", icon: "fireplace.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0xFF4500)),
        WizScene(id: 6, name: "Candlelight", icon: "flame.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0xFF9933)),
        WizScene(id: 7, name: "Forest", icon: "leaf.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0x2ECC71)),
        WizScene(id: 2, name: "Romance", icon: "heart.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0xFF3366)),
        WizScene(id: 20, name: "Aurora / Spring", icon: "sun.horizon.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0x13C4A3)),
        WizScene(id: 31, name: "Pulse", icon: "waveform.path", isDynamic: true, previewColor: NSColor(hexRGB: 0x38EF7D)),
        WizScene(id: 32, name: "Steampunk", icon: "gearshape.2.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0xDDA15E)),
        WizScene(id: 35, name: "Alarm", icon: "bell.badge.fill", isDynamic: true, previewColor: NSColor(hexRGB: 0xFF1744)),

        // Static White Ambiances
        WizScene(id: 11, name: "Warm White", icon: "sun.haze.fill", isDynamic: false, previewColor: NSColor(hexRGB: 0xFFD180)),
        WizScene(id: 12, name: "Daylight", icon: "sun.max.fill", isDynamic: false, previewColor: NSColor(hexRGB: 0xFFF9E6)),
        WizScene(id: 13, name: "Cool White", icon: "snowflake", isDynamic: false, previewColor: NSColor(hexRGB: 0xDDF3FF)),
        WizScene(id: 14, name: "Night Light", icon: "moon.stars.fill", isDynamic: false, previewColor: NSColor(hexRGB: 0xCC7722))
    ]

    private let networkQueue = DispatchQueue(label: "com.lumina.network", qos: .userInitiated)
    private var debounceWorkItem: DispatchWorkItem?
    private var pollTimer: Timer?
    private var controlRevision: UInt64 = 0
    private var lastLocalControlAt = Date.distantPast
    private let udpPort: UInt16 = 38899

    private init() {
        let savedIP = UserDefaults.standard.string(forKey: DefaultsKey.bulbIP) ?? Defaults.defaultIP
        self.ipAddress = savedIP

        let savedSpeed = UserDefaults.standard.double(forKey: DefaultsKey.dynamicSpeed)
        self.dynamicSpeed = savedSpeed >= 20.0 ? savedSpeed : Defaults.defaultSpeed

        // Initial fetch
        refreshStatus()

        // Periodic background poll every 4 seconds
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                self?.refreshStatus()
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - UDP Payload Formatting

    public static func makePilotPayload(params: [String: Any]) -> [String: Any] {
        return [
            "method": "setPilot",
            "env": "pro",
            "params": params
        ]
    }

    public static func makeGetPilotPayload() -> [String: Any] {
        return [
            "method": "getPilot",
            "env": "pro",
            "params": [:] as [String: Any]
        ]
    }

    // MARK: - UDP Socket Communication

    private func sendUDP(payload: [String: Any], host: String, timeout: TimeInterval = 1.0) -> [String: Any]? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        let sec = Int(timeout)
        let usec = Int32((timeout.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
        var tv = timeval(tv_sec: sec, tv_usec: usec)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(udpPort.bigEndian)
        inet_pton(AF_INET, host, &addr.sin_addr)

        let sent = withUnsafePointer(to: &addr) { ptr -> Int in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                jsonData.withUnsafeBytes { rawPtr in
                    sendto(fd, rawPtr.baseAddress, jsonData.count, 0, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        guard sent > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: 4096)
        var srcAddr = sockaddr_in()
        var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let recvd = withUnsafeMutablePointer(to: &srcAddr) { ptr -> Int in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                recvfrom(fd, &buffer, buffer.count, 0, saPtr, &srcLen)
            }
        }

        guard recvd > 0 else { return nil }
        let receivedData = Data(buffer.prefix(recvd))
        return (try? JSONSerialization.jsonObject(with: receivedData, options: [])) as? [String: Any]
    }

    // MARK: - Public Controls

    public func togglePower() {
        setPower(!isOn)
    }

    public func setPower(_ state: Bool) {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        noteLocalControl()
        noteVisualChange()
        self.isOn = state
        sendPilotCommand(["state": state])
    }

    public func setBrightness(_ value: Double) {
        noteVisualChange()
        noteLocalControl()
        let clamped = max(10.0, min(100.0, value))
        self.brightness = clamped
        debouncePilotCommand {
            ["state": true, "dimming": Int(clamped)]
        }
    }

    public func setColor(_ newColor: NSColor) {
        noteVisualChange()
        noteLocalControl()
        self.color = newColor
        self.activeMode = .color
        self.activeSceneId = 0

        guard let rgb = newColor.usingColorSpace(.sRGB) else { return }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        let dimming = Int(self.brightness)

        debouncePilotCommand {
            [
                "state": true,
                "r": r,
                "g": g,
                "b": b,
                "dimming": dimming
            ]
        }
    }

    public func setTemperature(_ kelvin: Double) {
        noteVisualChange()
        noteLocalControl()
        let clamped = max(2200.0, min(6500.0, kelvin))
        self.temperature = clamped
        self.activeMode = .temperature
        self.activeSceneId = 0

        // Synchronize visual color representation with temperature
        self.color = kelvinToColor(clamped)

        debouncePilotCommand {
            [
                "state": true,
                "temp": Int(clamped)
            ]
        }
    }

    public func setScene(_ scene: WizScene) {
        noteVisualChange()
        noteLocalControl()
        self.activeSceneId = scene.id
        self.activeMode = .scenes
        self.color = scene.previewColor

        var params: [String: Any] = [
            "state": true,
            "sceneId": scene.id
        ]
        if scene.isDynamic {
            params["speed"] = Int(dynamicSpeed)
        }

        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        sendPilotCommand(params)
    }

    public func setSceneIdDirect(_ sceneId: Int, speed: Int? = nil, brightness: Double? = nil) {
        noteVisualChange()
        noteLocalControl()
        self.activeSceneId = sceneId
        self.activeMode = .scenes

        var params: [String: Any] = [
            "state": true,
            "sceneId": sceneId
        ]
        if let speed = speed {
            params["speed"] = speed
        }
        if let brightness = brightness {
            params["dimming"] = Int(max(10.0, min(100.0, brightness)))
        }

        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        sendPilotCommand(params)
    }

    public func setSpeed(_ speedValue: Double) {
        let clamped = max(20.0, min(100.0, speedValue))
        self.dynamicSpeed = clamped
        UserDefaults.standard.set(clamped, forKey: DefaultsKey.dynamicSpeed)

        // Only send if current mode is a dynamic scene
        guard activeMode == .scenes,
              let activeScene = availableScenes.first(where: { $0.id == activeSceneId }),
              activeScene.isDynamic else {
            return
        }

        debouncePilotCommand {
            [
                "state": true,
                "sceneId": activeScene.id,
                "speed": Int(clamped)
            ]
        }
    }

    public func selectMode(_ mode: BulbControlMode) {
        self.activeMode = mode
    }

    private func noteLocalControl() {
        controlRevision &+= 1
        lastLocalControlAt = Date()
    }

    private func noteVisualChange() {
        visualChangeToken &+= 1
    }

    private func debouncePilotCommand(payloadGenerator: @escaping () -> [String: Any]) {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.sendPilotCommand(payloadGenerator())
        }
        debounceWorkItem = workItem
        networkQueue.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func sendPilotCommand(_ params: [String: Any]) {
        let targetIP = self.ipAddress
        let payload: [String: Any] = [
            "method": "setPilot",
            "env": "pro",
            "params": params
        ]

        networkQueue.async { [weak self] in
            guard let self = self else { return }
            let response = self.sendUDP(payload: payload, host: targetIP, timeout: 0.8)

            DispatchQueue.main.async {
                if let resp = response, resp["error"] == nil {
                    self.isConnected = true
                    self.lastErrorMessage = nil
                } else {
                    if let err = response?["error"] as? [String: Any],
                       let code = err["code"] {
                        self.lastErrorMessage = "Bulb returned error code: \(code)"
                    }
                }
            }
        }
    }

    // MARK: - State Refresh & Status Polling

    public func refreshStatus() {
        let targetIP = self.ipAddress
        let payload: [String: Any] = [
            "method": "getPilot",
            "env": "pro",
            "params": [:] as [String: Any]
        ]

        let fetchRevision = self.controlRevision

        networkQueue.async { [weak self] in
            guard let self = self else { return }
            let response = self.sendUDP(payload: payload, host: targetIP, timeout: 1.0)

            DispatchQueue.main.async {
                // If the user operated local controls while this was in flight, ignore
                if fetchRevision != self.controlRevision || Date().timeIntervalSince(self.lastLocalControlAt) < 1.0 {
                    return
                }

                guard let resp = response,
                      let result = resp["result"] as? [String: Any] else {
                    self.isConnected = false
                    return
                }

                self.isConnected = true
                self.lastErrorMessage = nil

                if let state = result["state"] as? Bool {
                    self.isOn = state
                }
                if let dim = result["dimming"] as? Double {
                    self.brightness = dim
                }
                if let temp = result["temp"] as? Double {
                    self.temperature = temp
                    self.color = self.kelvinToColor(temp)
                }
                if let r = result["r"] as? Double,
                   let g = result["g"] as? Double,
                   let b = result["b"] as? Double {
                    self.color = NSColor(srgbRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1.0)
                }
                if let sceneId = result["sceneId"] as? Int, sceneId > 0 {
                    self.activeSceneId = sceneId
                }
                if let spd = result["speed"] as? Double {
                    self.dynamicSpeed = spd
                }
            }
        }
    }

    // MARK: - IP Rescan & Discovery

    public func rescanNetwork() {
        guard !isScanning else { return }
        isScanning = true

        networkQueue.async { [weak self] in
            guard let self = self else { return }

            let broadcastPayload: [String: Any] = [
                "method": "getPilot",
                "env": "pro",
                "params": [:] as [String: Any]
            ]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: broadcastPayload, options: []) else {
                DispatchQueue.main.async { self.isScanning = false }
                return
            }

            let fd = socket(AF_INET, SOCK_DGRAM, 0)
            guard fd >= 0 else {
                DispatchQueue.main.async { self.isScanning = false }
                return
            }
            defer { close(fd) }

            var broadcastEnable: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))

            var tv = timeval(tv_sec: 1, tv_usec: 500_000)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(self.udpPort.bigEndian)
            inet_pton(AF_INET, "255.255.255.255", &addr.sin_addr)

            _ = withUnsafePointer(to: &addr) { ptr -> Int in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    jsonData.withUnsafeBytes { rawPtr in
                        sendto(fd, rawPtr.baseAddress, jsonData.count, 0, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }

            var buffer = [UInt8](repeating: 0, count: 2048)
            var srcAddr = sockaddr_in()
            var srcLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let recvd = withUnsafeMutablePointer(to: &srcAddr) { ptr -> Int in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    recvfrom(fd, &buffer, buffer.count, 0, saPtr, &srcLen)
                }
            }

            if recvd > 0 {
                var ipStr = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &srcAddr.sin_addr, &ipStr, socklen_t(INET_ADDRSTRLEN))
                let discoveredIP = String(cString: ipStr)

                DispatchQueue.main.async {
                    self.ipAddress = discoveredIP
                    self.isScanning = false
                    self.refreshStatus()
                }
            } else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    if !self.isConnected {
                        self.lastErrorMessage = "Discovery broadcast timed out. Enter IP manually in Settings."
                    }
                }
            }
        }
    }

    // MARK: - Color Conversion Helpers

    public func kelvinToColor(_ kelvin: Double) -> NSColor {
        let temp = kelvin / 100.0
        var red: Double
        var green: Double
        var blue: Double

        // Red calculation
        if temp <= 66.0 {
            red = 255.0
        } else {
            red = temp - 60.0
            red = 329.698727446 * pow(red, -0.1332047592)
            red = max(0.0, min(255.0, red))
        }

        // Green calculation
        if temp <= 66.0 {
            green = temp
            green = 99.4708025861 * log(green) - 161.1195681661
            green = max(0.0, min(255.0, green))
        } else {
            green = temp - 60.0
            green = 288.1221695283 * pow(green, -0.0755148492)
            green = max(0.0, min(255.0, green))
        }

        // Blue calculation
        if temp >= 66.0 {
            blue = 255.0
        } else if temp <= 19.0 {
            blue = 0.0
        } else {
            blue = temp - 10.0
            blue = 138.5177312231 * log(blue) - 305.0447927307
            blue = max(0.0, min(255.0, blue))
        }

        return NSColor(srgbRed: CGFloat(red / 255.0),
                       green: CGFloat(green / 255.0),
                       blue: CGFloat(blue / 255.0),
                       alpha: 1.0)
    }
}
