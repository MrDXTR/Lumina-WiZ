import SwiftUI

public struct SettingsPopoverView: View {
    @ObservedObject var wiz: WizService
    @ObservedObject var vm: MainViewModel

    public init(wiz: WizService = .shared, vm: MainViewModel) {
        self.wiz = wiz
        self.vm = vm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bulb Settings")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Bulb IP Address:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("192.168.0.5", text: $vm.customIP)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button("Save") {
                        wiz.ipAddress = vm.customIP
                        vm.showingSettings = false
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            Text("Local Security Note:")
                .font(.system(size: 11, weight: .medium))
            Text("In the WiZ App > Settings > Security, ensure 'Allow all controls' is selected for instant UDP control.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 240)
    }
}
