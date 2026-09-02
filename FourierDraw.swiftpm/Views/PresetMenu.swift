import SwiftUI
import Foundation

struct PresetMenu: View {
    @Binding var selectedPreset: Preset?
    let onSelect: (Preset) -> Void
    let onInteraction: () -> Void

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)

    init(
        selectedPreset: Binding<Preset?>,
        onSelect: @escaping (Preset) -> Void,
        onInteraction: @escaping () -> Void = {}
    ) {
        _selectedPreset = selectedPreset
        self.onSelect = onSelect
        self.onInteraction = onInteraction
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onInteraction()
                        isExpanded = false
                    }
                    .accessibilityHidden(true)
            }

            VStack(alignment: .trailing, spacing: 8) {
                menuButton

                if isExpanded {
                    menuPanel
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private var menuButton: some View {
        Button {
            onInteraction()
            isExpanded.toggle()
        } label: {
            Image(systemName: "star")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ink.opacity(0.78))
                .frame(width: 44, height: 44)
                .background(
                    .white.opacity(reduceTransparency ? 1 : 0.78),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(ink.opacity(0.14), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("预设图形，当前\(selectedPreset?.name ?? "手绘图形")")
        .accessibilityHint(isExpanded ? "关闭预设菜单" : "打开预设菜单")
    }

    private var menuPanel: some View {
        VStack(spacing: 0) {
            ForEach(Preset.allCases) { preset in
                Button {
                    onInteraction()
                    selectedPreset = preset
                    isExpanded = false
                    onSelect(preset)
                } label: {
                    Text(preset.name)
                        .font(.body)
                        .foregroundStyle(
                            selectedPreset == preset
                                ? ink
                                : ink.opacity(0.6)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(
                            selectedPreset == preset
                                ? ink.opacity(0.07)
                                : .clear
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.name)
                .accessibilityHint("选择预设图形")
                .accessibilityAddTraits(
                    selectedPreset == preset ? .isSelected : []
                )
            }
        }
        .padding(.vertical, 5)
        .frame(minWidth: 156)
        .background(
            .white.opacity(reduceTransparency ? 1 : 0.92),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ink.opacity(0.10), lineWidth: 1)
        }
    }
}
