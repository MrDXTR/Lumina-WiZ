import SwiftUI
import AppKit

public struct ColorWheelView: View {
    @Binding var selectedColor: NSColor
    let onColorChanged: (NSColor) -> Void

    @StateObject private var vm: ColorWheelViewModel

    private let wheelDiameter: CGFloat = 148.0
    private var radius: CGFloat { wheelDiameter / 2.0 }

    // Quick presets
    private let presetColors: [NSColor] = [
        NSColor(srgbRed: 1.0, green: 0.85, blue: 0.65, alpha: 1.0), // Warm Candle
        NSColor(srgbRed: 1.0, green: 0.40, blue: 0.20, alpha: 1.0), // Sunset Amber
        NSColor(srgbRed: 0.95, green: 0.15, blue: 0.30, alpha: 1.0), // Crimson
        NSColor(srgbRed: 0.70, green: 0.20, blue: 0.95, alpha: 1.0), // Neon Purple
        NSColor(srgbRed: 0.20, green: 0.50, blue: 1.00, alpha: 1.0), // Deep Blue
        NSColor(srgbRed: 0.10, green: 0.85, blue: 0.85, alpha: 1.0), // Cyan
        NSColor(srgbRed: 0.20, green: 0.85, blue: 0.35, alpha: 1.0), // Emerald
        NSColor(white: 0.98, alpha: 1.0)                             // Pure White
    ]

    public init(selectedColor: Binding<NSColor>, onColorChanged: @escaping (NSColor) -> Void) {
        self._selectedColor = selectedColor
        self.onColorChanged = onColorChanged
        self._vm = StateObject(wrappedValue: ColorWheelViewModel())
    }

    public var body: some View {
        VStack(spacing: 8) {
            // The Radial Color Wheel
            ZStack {
                // Hue Angular Gradient
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.0, blue: 0.0),
                                Color(red: 1.0, green: 1.0, blue: 0.0),
                                Color(red: 0.0, green: 1.0, blue: 0.0),
                                Color(red: 0.0, green: 1.0, blue: 1.0),
                                Color(red: 0.0, green: 0.0, blue: 1.0),
                                Color(red: 1.0, green: 0.0, blue: 1.0),
                                Color(red: 1.0, green: 0.0, blue: 0.0)
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: wheelDiameter, height: wheelDiameter)

                // Saturation Gradient (white in center, transparent at edge)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.white, Color.white.opacity(0.0)]),
                            center: .center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                    .frame(width: wheelDiameter, height: wheelDiameter)

                // Subtle edge stroke
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: wheelDiameter, height: wheelDiameter)

                // Draggable Selector Puck
                Circle()
                    .fill(Color(selectedColor))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2.5)
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                    )
                    .scaleEffect(vm.isDragging ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: vm.isDragging)
                    .position(
                        x: radius + vm.knobPosition.x,
                        y: radius + vm.knobPosition.y
                    )
            }
            .frame(width: wheelDiameter, height: wheelDiameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        vm.isDragging = true
                        updateFromPoint(value.location)
                    }
                    .onEnded { _ in
                        vm.isDragging = false
                    }
            )
            .onAppear {
                syncKnobFromColor(selectedColor)
                vm.hexText = selectedColor.hexString
            }
            .onChange(of: selectedColor) { newColor in
                if !vm.isDragging {
                    syncKnobFromColor(newColor)
                }
                vm.hexText = newColor.hexString
            }

            // Color Presets Bar
            HStack(spacing: 8) {
                ForEach(0..<presetColors.count, id: \.self) { idx in
                    let col = presetColors[idx]
                    Button(action: {
                        selectedColor = col
                        syncKnobFromColor(col)
                        onColorChanged(col)
                    }) {
                        Circle()
                            .fill(Color(col))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)

            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(selectedColor))
                    .frame(width: 18, height: 18)
                TextField("#RRGGBB", text: $vm.hexText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit(applyHexColor)
                Button("Apply", action: applyHexColor)
                    .controlSize(.small)
            }
        }
    }

    private func applyHexColor() {
        guard let color = NSColor(hex: vm.hexText) else { return }
        selectedColor = color
        syncKnobFromColor(color)
        onColorChanged(color)
        vm.hexText = color.hexString
    }

    // MARK: - Color Math

    private func updateFromPoint(_ point: CGPoint) {
        let dx = point.x - radius
        let dy = point.y - radius
        let distance = sqrt(dx * dx + dy * dy)
        let clampedDist = min(radius, distance)

        let angle = atan2(dy, dx)
        let knobX = clampedDist * cos(angle)
        let knobY = clampedDist * sin(angle)
        vm.knobPosition = CGPoint(x: knobX, y: knobY)

        // Calculate Hue and Saturation
        var hue = (angle >= 0 ? angle : (2 * .pi + angle)) / (2 * .pi)
        // Normalize angle
        hue = hue.truncatingRemainder(dividingBy: 1.0)

        let saturation = clampedDist / radius
        let newColor = NSColor(hue: CGFloat(hue),
                               saturation: CGFloat(saturation),
                               brightness: 1.0,
                               alpha: 1.0)

        self.selectedColor = newColor
        self.onColorChanged(newColor)
    }

    private func syncKnobFromColor(_ color: NSColor) {
        guard let hsb = color.usingColorSpace(.deviceRGB) else { return }
        let hue = hsb.hueComponent
        let saturation = hsb.saturationComponent

        let angle = Double(hue) * 2.0 * .pi
        let dist = Double(saturation) * Double(radius)

        vm.knobPosition = CGPoint(
            x: CGFloat(dist * cos(angle)),
            y: CGFloat(dist * sin(angle))
        )
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
                  green: CGFloat((rgb >> 8) & 0xff) / 255,
                  blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.deviceRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}
