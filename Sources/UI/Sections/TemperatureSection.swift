import SwiftUI

public struct TemperatureSection: View {
    @ObservedObject var wiz: WizService
    @ObservedObject var vm: MainViewModel

    public init(wiz: WizService = .shared, vm: MainViewModel) {
        self.wiz = wiz
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 6) {
                HStack(alignment: .center) {
                    Text("Color Temperature")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()

                    // Kelvin Numeric Input Field
                    HStack(spacing: 3) {
                        TextField("3500", text: $vm.tempInputText)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 44)
                            .onSubmit {
                                applyTempFromInput()
                            }

                        Text("K")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
                    )
                }

                // Interactive Gradient Glide Slider with Visible Pointer Thumb
                kelvinSliderTrack
            }
            .padding(10)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 10), interactive: false)

            // Quick Kelvin Presets
            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    tempPresetButton(name: "Candlelight", kelvin: 2200, icon: "flame.fill")
                    tempPresetButton(name: "Warm White", kelvin: 2700, icon: "sun.haze.fill")
                }
                HStack(spacing: 7) {
                    tempPresetButton(name: "Neutral", kelvin: 4000, icon: "sun.dust.fill")
                    tempPresetButton(name: "Daylight", kelvin: 6500, icon: "sun.max.fill")
                }
            }

            Spacer()
        }
        .padding(.top, 4)
        .onAppear {
            vm.syncTemperature(wiz.temperature)
        }
        .onChange(of: wiz.temperature) { newTemp in
            if !vm.isDraggingTemp {
                vm.syncTemperature(newTemp)
            }
        }
    }

    private var kelvinSliderTrack: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let thumbDiameter: CGFloat = 22.0
            let thumbRadius = thumbDiameter / 2.0
            let usableWidth = max(1.0, trackWidth - thumbDiameter)
            let clampedTemp = max(2200.0, min(6500.0, wiz.temperature))
            let progress = CGFloat((clampedTemp - 2200.0) / (6500.0 - 2200.0))
            let thumbX = thumbRadius + progress * usableWidth

            ZStack(alignment: .leading) {
                // Gradient Track
                RoundedRectangle(cornerRadius: 7)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )

                // Draggable Circular Pointer Thumb
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1.5)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        )

                    Circle()
                        .fill(Color(wiz.kelvinToColor(clampedTemp)))
                        .frame(width: 13, height: 13)
                }
                .scaleEffect(vm.isDraggingTemp ? 1.18 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: vm.isDraggingTemp)
                .position(x: thumbX, y: 8)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        vm.isDraggingTemp = true
                        let x = value.location.x
                        let ratio = min(max(0.0, (x - thumbRadius) / usableWidth), 1.0)
                        let rawKelvin = 2200.0 + Double(ratio) * 4300.0
                        let roundedKelvin = round(rawKelvin / 25.0) * 25.0
                        wiz.setTemperature(roundedKelvin)
                        vm.syncTemperature(roundedKelvin)
                    }
                    .onEnded { _ in
                        vm.isDraggingTemp = false
                    }
            )
        }
        .frame(height: 22)
    }

    private func applyTempFromInput() {
        if let val = Double(vm.tempInputText.trimmingCharacters(in: .whitespaces)) {
            let clamped = max(2200.0, min(6500.0, val))
            wiz.setTemperature(clamped)
            vm.syncTemperature(clamped)
        } else {
            vm.syncTemperature(wiz.temperature)
        }
    }

    private func tempPresetButton(name: String, kelvin: Double, icon: String) -> some View {
        let isSelected = abs(wiz.temperature - kelvin) < 150
        return Button(action: {
            wiz.setTemperature(kelvin)
            vm.syncTemperature(kelvin)
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
}
