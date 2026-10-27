import SwiftUI
import AppKit

public struct MainView: View {
    @ObservedObject var wiz = WizService.shared
    @ObservedObject var vm = MainViewModel.shared
    @ObservedObject var schedule = ScheduleManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HeaderSection(wiz: wiz)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            // Active Alarm Alert Banner
            if schedule.isAlarmTriggered {
                ActiveAlarmBanner(schedule: schedule)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 3D bulb remains on a transparent background; it bobs only when a control changes.
            Bulb3DView(isOn: wiz.isOn, color: wiz.color, brightness: wiz.brightness, visualChangeToken: wiz.visualChangeToken)
                .frame(height: 130)
                .padding(.bottom, 4)

            // Sleek, Compact Tab Bar (Color | White | Scenes | Alarm)
            TabBarSection(wiz: wiz)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            // Mode Content View
            Group {
                switch wiz.activeMode {
                case .color:
                    ColorWheelView(selectedColor: $wiz.color) { newColor in
                        wiz.setColor(newColor)
                    }
                    .frame(height: 220)
                    .disabled(!wiz.isOn)
                    .opacity(wiz.isOn ? 1.0 : 0.4)

                case .temperature:
                    TemperatureSection(wiz: wiz, vm: vm)
                        .frame(height: 220)
                    .disabled(!wiz.isOn)
                    .opacity(wiz.isOn ? 1.0 : 0.4)

                case .scenes:
                    ScenesSection(wiz: wiz)
                        .frame(height: 220)
                    .disabled(!wiz.isOn)
                    .opacity(wiz.isOn ? 1.0 : 0.4)

                case .alarms:
                    AlarmsSection(schedule: schedule, vm: vm)
                        .frame(height: 220)
                }
            }
            .padding(.horizontal, 18)

            Divider()
                .padding(.vertical, 6)
                .padding(.horizontal, 16)

            // Brightness Slider
            BrightnessSection(wiz: wiz)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
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
                .padding(.bottom, 5)
            }

            // Footer Action Bar
            FooterSection(wiz: wiz, vm: vm)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .padding(.top, 2)
        }
        .frame(width: 330, height: 515)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .overlay(Color.white.opacity(0.035))
        )
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
