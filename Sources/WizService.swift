import Foundation
import AppKit
import Combine

public enum BulbControlMode: String, CaseIterable, Identifiable {
    case color = "Color"
    case temperature = "White"
    case scenes = "Scenes"

    public var id: String { rawValue }
}

public struct WizScene: Identifiable {
    public let id: Int
    public let name: String
    public let icon: String
}

public final class WizService: ObservableObject {
    public static let shared = WizService()

    @Published public var ipAddress: String {
        didSet {
            UserDefaults.standard.set(ipAddress, forKey: "WizBulbIP")
            refreshStatus()
        }
    }

    @Published public var isOn: Bool = false
    @Published public var brightness: Double = 100.0 // 10 to 100
    @Published public var color: NSColor = NSColor(srgbRed: 1.0, green: 0.85, blue: 0.65, alpha: 1.0)
    @Published public var temperature: Double = 3500.0 // 2200 to 6500 Kelvin
    @Published public var activeMode: BulbControlMode = .temperature
    @Published public var activeSceneId: Int = 0
    @Published public var isConnected: Bool = false
    @Published public var isScanning: Bool = false
    @Published public var lastErrorMessage: String? = nil

    public let availableScenes: [WizScene] = [
        WizScene(id: 6, name: "Candlelight", icon: "flame.fill"),
        WizScene(id: 11, name: "Warm White", icon: "sun.haze.fill"),
        WizScene(id: 12, name: "Daylight", icon: "sun.max.fill"),
        WizScene(id: 13, name: "Cool White", icon: "snowflake"),
        WizScene(id: 14, name: "Night Light", icon: "moon.stars.fill"),
        WizScene(id: 1, name: "Ocean", icon: "water.waves"),
        WizScene(id: 2, name: "Sunset", icon: "sunset.fill"),
        WizScene(id: 3, name: "Party", icon: "sparkles"),
        WizScene(id: 4, name: "Fireplace", icon: "fireplace.fill"),
        WizScene(id: 5, name: "Forest", icon: "leaf.fill")
    ]

    private let networkQueue = DispatchQueue(label: "com.lumina.network", qos: .userInitiated)
    private var debounceWorkItem: DispatchWorkItem?
    private var pollTimer: Timer?
    private let udpPort: UInt16 = 38899

    private init() {
        let savedIP = UserDefaults.standard.string(forKey: "WizBulbIP") ?? "192.168.0.5"
        self.ipAddress = savedIP

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
        self.isOn = state
        sendPilotCommand(["state": state])
    }

    public func setBrightness(_ value: Double) {
        let clamped = max(10.0, min(100.0, value))
        self.brightness = clamped
        debouncePilotCommand {
            ["state": true, "dimming": Int(clamped)]
        }
    }

    public func setColor(_ newColor: NSColor) {
        self.color = newColor
        self.activeMode = .color

        guard let rgb = newColor.usingColorSpace(.sRGB) else { return }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))

        debouncePilotCommand {
            [
                "state": true,
                "r": r,
                "g": g,
                "b": b,
                "dimming": Int(self.brightness)
            ]
        }
    }

    public func setTemperature(_ kelvin: Double) {
        let clamped = max(2200.0, min(6500.0, kelvin))
        self.temperature = clamped
        self.activeMode = .temperature

        // Approximate color for 3D representation
        self.color = kelvinToColor(kelvin)

        debouncePilotCommand {
            [
                "state": true,
                "temp": Int(clamped),
                "dimming": Int(self.brightness)
            ]
        }
    }

    public func setScene(_ scene: WizScene) {
        self.activeSceneId = scene.id
        self.activeMode = .scenes

        debouncePilotCommand {
            [
                "state": true,
                "sceneId": scene.id,
                "dimming": Int(self.brightness)
            ]
        }
    }

    // MARK: - Pilot Command Execution

    private func debouncePilotCommand(payloadGenerator: @escaping () -> [String: Any]) {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            let payload = payloadGenerator()
            self?.sendPilotCommand(payload)
        }
        debounceWorkItem = item
        networkQueue.asyncAfter(deadline: .now() + 0.04, execute: item)
    }

    private func sendPilotCommand(_ params: [String: Any]) {
        let currentIP = self.ipAddress
        networkQueue.async { [weak self] in
            guard let self = self else { return }
            let req: [String: Any] = [
                "method": "setPilot",
                "params": params
            ]
            let resp = self.sendUDP(payload: req, host: currentIP, timeout: 0.8)

            DispatchQueue.main.async {
                if let resp = resp {
                    if let result = resp["result"] as? [String: Any], (result["success"] as? Bool) == true {
                        self.isConnected = true
                        self.lastErrorMessage = nil
                    } else if let error = resp["error"] as? [String: Any] {
                        let code = error["code"] as? Int ?? 0
                        if code == -32602 {
                            self.lastErrorMessage = "Bulb requires 'Allow all controls' in WiZ App (Settings > Security)."
                        } else {
                            self.lastErrorMessage = error["message"] as? String ?? "Command error"
                        }
                    }
                } else {
                    self.isConnected = false
                    self.lastErrorMessage = "No response from \(currentIP)"
                }
            }
        }
    }

    // MARK: - Query State

    public func refreshStatus() {
        let currentIP = self.ipAddress
        networkQueue.async { [weak self] in
            guard let self = self else { return }
            let req: [String: Any] = ["method": "getPilot", "params": [:]]
            let resp = self.sendUDP(payload: req, host: currentIP, timeout: 0.8)

            DispatchQueue.main.async {
                guard let resp = resp else {
                    self.isConnected = false
                    return
                }

                self.isConnected = true
                self.lastErrorMessage = nil

                if let result = resp["result"] as? [String: Any] {
                    if let state = result["state"] as? Bool {
                        self.isOn = state
                    }
                    if let dimming = result["dimming"] as? Int {
                        self.brightness = Double(dimming)
                    }
                    if let temp = result["temp"] as? Int {
                        self.temperature = Double(temp)
                        if (result["sceneId"] as? Int ?? 0) == 0 && result["r"] == nil {
                            self.activeMode = .temperature
                            self.color = self.kelvinToColor(Double(temp))
                        }
                    }
                    if let r = result["r"] as? Int, let g = result["g"] as? Int, let b = result["b"] as? Int {
                        self.color = NSColor(srgbRed: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: 1.0)
                        self.activeMode = .color
                    }
                    if let sceneId = result["sceneId"] as? Int, sceneId > 0 {
                        self.activeSceneId = sceneId
                        self.activeMode = .scenes
                    }
                }
            }
        }
    }

    // MARK: - Auto Network Discovery

    public func rescanNetwork() {
        guard !isScanning else { return }
        isScanning = true
        lastErrorMessage = "Scanning network..."

        networkQueue.async { [weak self] in
            guard let self = self else { return }

            // Subnet 192.168.0.x
            let group = DispatchGroup()
            var discoveredIP: String? = nil
            let lock = NSLock()

            for i in 1...254 {
                let candidateIP = "192.168.0.\(i)"
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    let req: [String: Any] = ["method": "getPilot", "params": [:]]
                    if let resp = self.sendUDP(payload: req, host: candidateIP, timeout: 0.35) {
                        if resp["result"] != nil || resp["method"] as? String == "getPilot" {
                            lock.lock()
                            if discoveredIP == nil {
                                discoveredIP = candidateIP
                            }
                            lock.unlock()
                        }
                    }
                    group.leave()
                }
            }

            group.wait()

            DispatchQueue.main.async {
                self.isScanning = false
                if let found = discoveredIP {
                    self.ipAddress = found
                    self.lastErrorMessage = nil
                    self.refreshStatus()
                } else {
                    self.lastErrorMessage = "Bulb not found on network."
                }
            }
        }
    }

    // MARK: - Color Temp Helper

    public func kelvinToColor(_ kelvin: Double) -> NSColor {
        let temp = kelvin / 100.0
        var red: Double
        var green: Double
        var blue: Double

        // Red
        if temp <= 66 {
            red = 255
        } else {
            red = temp - 60
            red = 329.698727446 * pow(red, -0.1332047592)
            red = max(0, min(255, red))
        }

        // Green
        if temp <= 66 {
            green = temp
            green = 99.4708025861 * log(green) - 161.1195681661
            green = max(0, min(255, green))
        } else {
            green = temp - 60
            green = 288.1221695283 * pow(green, -0.0755148492)
            green = max(0, min(255, green))
        }

        // Blue
        if temp >= 66 {
            blue = 255
        } else if temp <= 19 {
            blue = 0
        } else {
            blue = temp - 10
            blue = 138.5177312231 * log(blue) - 305.0447927307
            blue = max(0, min(255, blue))
        }

        return NSColor(srgbRed: CGFloat(red / 255.0),
                       green: CGFloat(green / 255.0),
                       blue: CGFloat(blue / 255.0),
                       alpha: 1.0)
    }
}
