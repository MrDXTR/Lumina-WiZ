import SwiftUI
import AppKit

public struct ColorWheelView: View {
    @Binding var selectedColor: NSColor
    let onColorChanged: (NSColor) -> Void

    @StateObject private var vm: ColorWheelViewModel

    private let wheelDiameter: CGFloat = 130.0
    private var radius: CGFloat { wheelDiameter / 2.0 }

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
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .frame(width: wheelDiameter, height: wheelDiameter)

                // Draggable Selector Puck
                Circle()
                    .fill(Color(selectedColor))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2.2)
                            .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
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

            // Favorites Bar (Up to 5 colors)
            favoritesSection

            // Hex Input and Preview
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(selectedColor))
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                TextField("#RRGGBB", text: $vm.hexText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit(applyHexColor)

                Button("Apply", action: applyHexColor)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        HStack(spacing: 8) {
            Text("FAVORITES")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 7) {
                ForEach(Array(vm.favoriteColors.enumerated()), id: \.offset) { index, hex in
                    let col = NSColor(hex: hex) ?? .white
                    Button {
                        selectedColor = col
                        syncKnobFromColor(col)
                        onColorChanged(col)
                        vm.hexText = hex
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Circle()
                                .fill(Color(col))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(selectedColor.hexString == hex ? 0.9 : 0.25), lineWidth: selectedColor.hexString == hex ? 2 : 1)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Apply Color") {
                            selectedColor = col
                            syncKnobFromColor(col)
                            onColorChanged(col)
                        }
                        Button("Replace with Current") {
                            vm.replaceFavorite(at: index, with: selectedColor.hexString)
                        }
                        Divider()
                        Button("Remove Favorite", role: .destructive) {
                            vm.removeFavorite(at: index)
                        }
                    }
                }

                // Add Current Color Button if less than 5
                if vm.favoriteColors.count < 5 {
                    Button {
                        vm.addCurrentColorAsFavorite(selectedColor.hexString)
                    } label: {
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2]))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Add current color to favorites (up to 5)")
                }
            }

            Spacer(minLength: 0)

            Text("\(vm.favoriteColors.count)/5")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 8), interactive: false)
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

        var hue = (angle >= 0 ? angle : (2 * .pi + angle)) / (2 * .pi)
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
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xff) / 255.0,
                  green: CGFloat((rgb >> 8) & 0xff) / 255.0,
                  blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.deviceRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}
