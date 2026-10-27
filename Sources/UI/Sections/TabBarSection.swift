import SwiftUI

public struct TabBarSection: View {
    @ObservedObject var wiz: WizService

    public init(wiz: WizService = .shared) {
        self.wiz = wiz
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(BulbControlMode.allCases) { mode in
                let isSelected = wiz.activeMode == mode
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        wiz.selectMode(mode)
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.accentColor.opacity(0.85))
                                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }
}
