import SwiftUI
import AppKit

// MARK: - Liquid Glass View Modifier

/// Applies Apple's modern Liquid Glass material on macOS 26.0+ with smooth
/// fallback to vibrancy and materials on earlier macOS versions.
public struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    public init(shape: S, interactive: Bool = true) {
        self.shape = shape
        self.interactive = interactive
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                content
                    .glassEffect(.regular.interactive(), in: shape)
            } else {
                content
                    .glassEffect(.regular, in: shape)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        }
    }
}

public extension View {
    /// Applies Liquid Glass with dynamic refraction on macOS 26+, or refined material on earlier versions.
    func liquidGlass<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        modifier(LiquidGlassModifier(shape: shape, interactive: interactive))
    }
}
