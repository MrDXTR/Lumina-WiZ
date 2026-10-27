import SwiftUI
import AppKit

public struct MainView: View {
    @ObservedObject var wiz = WizService.shared
    @ObservedObject var vm = MainViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            // 3D Bulb View (Interactive live render)
            ZStack {
                // Subtle ambient glow behind the 3D bulb
                if wiz.isOn {
                    Circle()
                        .fill(Color(wiz.color).opacity(0.25 * (wiz.brightness / 100.0)))
                        .frame(width: 130, height: 130)
                        .blur(radius: 25)
                        .offset(y: -10)
                }

                Bulb3DView(isOn: wiz.isOn, color: wiz.color, brightness: wiz.brightness)
                    .frame(height: 175)
            }
            .padding(.bottom, 6)

            // Mode Selector (Color / Warmth / Scenes)
            Picker("Mode", selection: $wiz.activeMode) {
                ForEach(BulbControlMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .disabled(!wiz.isOn)

            // Mode Content View
            Group {
                switch wiz.activeMode {
                case .color:
                    ColorWheelView(selectedColor: $wiz.color) { newColor in
                        wiz.setColor(newColor)
                    }
                    .frame(height: 215)

                case .temperature:
                    temperatureControlView
                        .frame(height: 215)

                case .scenes:
                    scenesGridView
                        .frame(height: 215)
                }
            }
            .padding(.horizontal, 18)
            .disabled(!wiz.isOn)
            .opacity(wiz.isOn ? 1.0 : 0.4)

            Divider()
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

            // Brightness Slider
            brightnessSection
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .disabled(!wiz.isOn)
                .opacity(wiz.isOn ? 1.0 : 0.4)

            // Error banner if any
            if let errorMsg = wiz.lastErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(errorMsg)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Footer Action Bar
            footerSection
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .padding(.top, 4)
        }
        .frame(width: 330)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
        )
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Philips WiZ Neo")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                HStack(spacing: 5) {
                    Circle()
                        .fill(wiz.isConnected ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(wiz.isConnected ? "Connected • \(wiz.ipAddress)" : (wiz.isScanning ? "Scanning..." : "Offline"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Big tactile Power Button
            Button(action: {
                wiz.togglePower()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            wiz.isOn
                            ? AnyShapeStyle(Color(wiz.color).opacity(0.2))
                            : AnyShapeStyle(Color.primary.opacity(0.08))
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(wiz.isOn ? Color(wiz.color) : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        )

                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(wiz.isOn ? Color(wiz.color) : .secondary)
                }
            }
            .buttonStyle(.plain)
            .shadow(color: wiz.isOn ? Color(wiz.color).opacity(0.4) : .clear, radius: 6, x: 0, y: 1)
        }
    }

    private var brightnessSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { wiz.brightness },
                    set: { wiz.setBrightness($0) }
                ), in: 10...100, step: 1)
                .accentColor(Color(wiz.color))

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text("\(Int(wiz.brightness))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    private var temperatureControlView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Color Temperature")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(Int(wiz.temperature)) K")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Kelvin Gradient Track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.58, blue: 0.22), // 2200K
                                        Color(red: 1.0, green: 0.82, blue: 0.55), // 3000K
                                        Color(red: 1.0, green: 0.95, blue: 0.90), // 4500K
                                        Color(red: 0.80, green: 0.90, blue: 1.0)  // 6500K
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 14)

                        // Slider overlay
                        Slider(value: Binding(
                            get: { wiz.temperature },
                            set: { wiz.setTemperature($0) }
                        ), in: 2200...6500, step: 50)
                        .opacity(0.05)
                    }
                }
                .frame(height: 20)
            }

            // Quick Kelvin Presets
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    tempPresetButton(name: "Candlelight", kelvin: 2200, icon: "flame.fill")
                    tempPresetButton(name: "Warm White", kelvin: 2700, icon: "sun.haze.fill")
                }
                HStack(spacing: 8) {
                    tempPresetButton(name: "Neutral", kelvin: 4000, icon: "sun.dust.fill")
                    tempPresetButton(name: "Daylight", kelvin: 6500, icon: "sun.max.fill")
                }
            }

            Spacer()
        }
        .padding(.top, 10)
    }

    private func tempPresetButton(name: String, kelvin: Double, icon: String) -> some View {
        let isSelected = abs(wiz.temperature - kelvin) < 150
        return Button(action: {
            wiz.setTemperature(kelvin)
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(name)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var scenesGridView: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(wiz.availableScenes) { scene in
                    let isSelected = wiz.activeSceneId == scene.id
                    Button(action: {
                        wiz.setScene(scene)
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: scene.icon)
                                .font(.system(size: 13))
                                .foregroundColor(isSelected ? .white : .primary)
                            Text(scene.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isSelected ? .white : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }

    private var footerSection: some View {
        HStack {
            // Settings button
            Button(action: {
                vm.showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $vm.showingSettings) {
                settingsPopover
            }

            // Rescan button
            Button(action: {
                wiz.rescanNetwork()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text(wiz.isScanning ? "Scanning..." : "Rescan IP")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(wiz.isScanning)

            Spacer()

            // Quit App button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bulb Settings")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Bulb IP Address:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("192.168.0.5", text: $vm.customIP)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button("Save") {
                        wiz.ipAddress = vm.customIP
                        vm.showingSettings = false
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            Text("Local Security Note:")
                .font(.system(size: 11, weight: .medium))
            Text("In the WiZ App > Settings > Security, ensure 'Allow all controls' is selected for instant UDP control.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 240)
    }
}

// VisualEffectView for sleek native macOS vibrancy
public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    public func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
