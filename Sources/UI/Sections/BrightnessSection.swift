import SwiftUI

public struct BrightnessSection: View {
    @ObservedObject var wiz: WizService

    public init(wiz: WizService = .shared) {
        self.wiz = wiz
    }

    public var body: some View {
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
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}
