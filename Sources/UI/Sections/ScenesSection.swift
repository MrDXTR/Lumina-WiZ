import SwiftUI

public struct ScenesSection: View {
    @ObservedObject var wiz: WizService

    public init(wiz: WizService = .shared) {
        self.wiz = wiz
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                // Dynamic Lighting Speed Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "gauge.with.needle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Dynamic Scene Speed")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(Int(wiz.dynamicSpeed))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "tortoise.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Slider(value: Binding(
                            get: { wiz.dynamicSpeed },
                            set: { wiz.setSpeed($0) }
                        ), in: 20...100, step: 5)
                        .accentColor(Color(wiz.color))

                        Image(systemName: "hare.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 8), interactive: false)

                // Standalone Dynamic Scenes Header
                HStack {
                    Text("DYNAMIC SCENES (STANDALONE)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "bolt.badge.checkmark.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(wiz.availableScenes.filter { $0.isDynamic }) { scene in
                        let isSelected = wiz.activeSceneId == scene.id
                        Button(action: { wiz.setScene(scene) }) {
                            HStack(spacing: 6) {
                                Image(systemName: scene.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(scene.previewColor))
                                Text(scene.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // White Ambiances
                Text("WHITE AMBIANCES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(wiz.availableScenes.filter { !$0.isDynamic }) { scene in
                        let isSelected = wiz.activeSceneId == scene.id
                        Button(action: { wiz.setScene(scene) }) {
                            HStack(spacing: 6) {
                                Image(systemName: scene.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(scene.previewColor))
                                Text(scene.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
