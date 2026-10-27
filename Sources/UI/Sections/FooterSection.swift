import SwiftUI
import AppKit

public struct FooterSection: View {
    @ObservedObject var wiz: WizService
    @ObservedObject var vm: MainViewModel

    public init(wiz: WizService = .shared, vm: MainViewModel) {
        self.wiz = wiz
        self.vm = vm
    }

    public var body: some View {
        HStack {
            // Settings button
            Button(action: {
                vm.showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $vm.showingSettings) {
                SettingsPopoverView(wiz: wiz, vm: vm)
            }

            // Rescan button
            Button(action: {
                wiz.rescanNetwork()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text(wiz.isScanning ? "Scanning..." : "Rescan IP")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(wiz.isScanning)

            Spacer()

            // Quit App button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
