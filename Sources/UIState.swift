import SwiftUI
import Combine

public final class ColorWheelViewModel: ObservableObject {
    @Published public var knobPosition: CGPoint = .zero
    @Published public var isDragging: Bool = false

    public init() {}
}

public final class MainViewModel: ObservableObject {
    @Published public var showingSettings: Bool = false
    @Published public var customIP: String = ""

    public init() {
        self.customIP = WizService.shared.ipAddress
    }
}
