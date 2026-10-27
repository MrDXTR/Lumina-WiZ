import SwiftUI
import AppKit

public struct HeaderSection: View {
    @ObservedObject var wiz: WizService

    public init(wiz: WizService = .shared) {
        self.wiz = wiz
    }

    public var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(UserDefaults.standard.string(forKey: DefaultsKey.bulbLabel) ?? Defaults.defaultLabel)
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

            // Tactile Power Toggle Button
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
}
