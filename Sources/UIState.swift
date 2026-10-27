import SwiftUI
import Combine

public final class ColorWheelViewModel: ObservableObject {
    @Published public var knobPosition: CGPoint = .zero
    @Published public var isDragging: Bool = false
    @Published public var hexText: String = ""

    public init() {}
}

public final class MainViewModel: ObservableObject {
    @Published public var showingSettings: Bool = false
    @Published public var customIP: String = ""
    @Published public var bulbLabel: String {
        didSet { UserDefaults.standard.set(bulbLabel, forKey: "LuminaBulbLabel") }
    }

    public init() {
        self.customIP = WizService.shared.ipAddress
        self.bulbLabel = UserDefaults.standard.string(forKey: "LuminaBulbLabel") ?? "PHILIPS"
    }
}
