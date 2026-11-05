import SwiftUI
import AppKit

public struct SavedPresetsSection: View {
    @ObservedObject var wiz: WizService
    @ObservedObject var vm: MainViewModel
    @ObservedObject var presetsManager: SavedPresetsManager

    public init(
        wiz: WizService = .shared,
        vm: MainViewModel = .shared,
        presetsManager: SavedPresetsManager = .shared
    ) {
        self.wiz = wiz
        self.vm = vm
        self.presetsManager = presetsManager
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Save Current Light Action Bar
            saveCurrentCard

            // Saved Presets Header & Grid
            presetsContent
        }
        .frame(height: 220)
    }

    // MARK: - Save Current Light Card

    private var saveCurrentCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                // Live Swatch Preview of currently applied light
                ZStack {
                    Circle()
                        .fill(Color(wiz.color))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: Color(wiz.color).opacity(0.5), radius: 3, x: 0, y: 1)

                    if !wiz.isOn {
                        Image(systemName: "slash.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }

                Text(wiz.isOn ? "CURRENT: \(Int(wiz.brightness))%" : "CURRENT: OFF")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text("SAVE CURRENT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                TextField("Preset name (e.g. Cozy Warm)", text: $vm.newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onSubmit(saveCurrentPreset)

                Button(action: saveCurrentPreset) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Save")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 8), interactive: false)
    }

    // MARK: - Presets Content

    private var presetsContent: some View {
        VStack(spacing: 6) {
            HStack {
                Text("SAVED PRESETS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)

                if !presetsManager.presets.isEmpty {
                    Text("(\(presetsManager.presets.count))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()

                if !presetsManager.presets.isEmpty {
                    Text("Click to apply")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            if presetsManager.presets.isEmpty {
                emptyStateView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(presetsManager.presets) { preset in
                            presetCard(preset)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Preset Card Item

    private func presetCard(_ preset: SavedPreset) -> some View {
        let isActive = presetsManager.isPresetActive(preset, wiz: wiz)
        let isHovered = vm.hoveredPresetId == preset.id

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                presetsManager.applyPreset(preset, wiz: wiz)
            }
        } label: {
            HStack(spacing: 7) {
                // Color & Brightness Swatch
                ZStack {
                    Circle()
                        .fill(Color(preset.previewColor))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isActive ? 0.9 : 0.25), lineWidth: isActive ? 1.5 : 0.8)
                        )
                        .shadow(color: Color(preset.previewColor).opacity(isActive ? 0.6 : 0.25), radius: 3, x: 0, y: 1)

                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                        .foregroundColor(isActive ? .primary : .primary.opacity(0.9))
                        .lineLimit(1)

                    Text(preset.displaySubtitle)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Quick Delete on hover / active
                if isHovered {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            presetsManager.deletePreset(id: preset.id)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(3)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete preset")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isActive ? Color.accentColor.opacity(0.8) : (isHovered ? Color.white.opacity(0.2) : Color.white.opacity(0.08)),
                        lineWidth: isActive ? 1.2 : 0.8
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            vm.hoveredPresetId = hovering ? preset.id : nil
        }
        .contextMenu {
            Button("Apply to Light") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    presetsManager.applyPreset(preset, wiz: wiz)
                }
            }
            Button("Update with Current Light") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    presetsManager.updatePresetWithCurrentLight(id: preset.id, wiz: wiz)
                }
            }
            Divider()
            Button("Delete Preset", role: .destructive) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    presetsManager.deletePreset(id: preset.id)
                }
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Saved Presets")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Button("Restore Defaults") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    presetsManager.resetToDefaults()
                }
            }
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func saveCurrentPreset() {
        let name = vm.newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            presetsManager.saveCurrentLight(wiz: wiz, name: name)
            vm.newPresetName = ""
        }
    }
}
