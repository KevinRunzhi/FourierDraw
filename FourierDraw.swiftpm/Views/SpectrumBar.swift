import SwiftUI
import Foundation

struct SpectrumBar: View {
    let cycles: [Epicycle]
    let m: Int
    let selectedFrequency: Int?
    let onSelect: (Int) -> Void

    @ScaledMetric(relativeTo: .caption2) private var labelHeight = 14.0

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    init(
        cycles: [Epicycle],
        m: Int,
        selectedFrequency: Int? = nil,
        onSelect: @escaping (Int) -> Void = { _ in }
    ) {
        self.cycles = cycles
        self.m = m
        self.selectedFrequency = selectedFrequency
        self.onSelect = onSelect
    }

    var body: some View {
        GeometryReader { geometry in
            let amplitudes = visibleAmplitudes
            let maximumAmplitude = amplitudes.max() ?? 0

            VStack(spacing: 2) {
                Canvas { context, size in
                    let spacing = size.width / Double(amplitudes.count)
                    let barWidth = max(1, spacing * 0.56)

                    for index in amplitudes.indices {
                        let frequency = index - 32
                        let baseHeight = maximumAmplitude > 0
                            ? size.height * amplitudes[index] / maximumAmplitude
                            : 0
                        let isSelected = frequency == selectedFrequency
                        let height = min(
                            size.height,
                            baseHeight + (isSelected ? 2 : 0)
                        )
                        let rect = CGRect(
                            x: (Double(index) + 0.5) * spacing - barWidth / 2,
                            y: size.height - height,
                            width: barWidth,
                            height: height
                        )
                        let color = isSelected || abs(frequency) <= m
                            ? vermilion
                            : ink.opacity(0.16)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
                .frame(height: max(0, geometry.size.height - labelHeight - 2))

                Text("0")
                    .font(.caption2)
                    .foregroundStyle(ink.opacity(0.55))
                    .frame(height: labelHeight)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let frequency = spectrumFrequency(
                            at: value.location.x,
                            width: geometry.size.width
                        )
                        onSelect(frequency)
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("傅里叶频谱")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("上下轻扫选择负 32 到正 32 的频率")
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
        .accessibilityAction(named: "恢复自动观察") {
            if let selectedFrequency {
                onSelect(selectedFrequency)
            }
        }
    }

    private var visibleAmplitudes: [Double] {
        var amplitudes = Array(repeating: 0.0, count: 65)
        for cycle in cycles where (-32...32).contains(cycle.freq) {
            amplitudes[cycle.freq + 32] = cycle.amp
        }
        return amplitudes
    }

    private var accessibilityValue: String {
        let range = "显示频率负 32 到正 32，启用到绝对值 \(min(max(m, 0), 32))"
        guard let selectedFrequency else { return range }
        return "\(range)，当前观察 k 等于 \(selectedFrequency)"
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let nextFrequency: Int
        switch direction {
        case .increment:
            nextFrequency = min(32, selectedFrequency.map { $0 + 1 } ?? 0)
        case .decrement:
            nextFrequency = max(-32, selectedFrequency.map { $0 - 1 } ?? 0)
        @unknown default:
            return
        }
        guard nextFrequency != selectedFrequency else { return }
        onSelect(nextFrequency)
    }
}

func spectrumFrequency(at x: CGFloat, width: CGFloat) -> Int {
    guard width > 0 else { return 0 }
    let normalizedX = min(max(x / width, 0), 1)
    let index = min(64, Int(normalizedX * 65))
    return index - 32
}

#if DEBUG
func debugValidateSpectrumBar() {
    let width = 650.0
    assert(spectrumFrequency(at: -1, width: width) == -32)
    assert(spectrumFrequency(at: 0, width: width) == -32)
    assert(spectrumFrequency(at: width / 2, width: width) == 0)
    assert(spectrumFrequency(at: width, width: width) == 32)
    assert(spectrumFrequency(at: width + 1, width: width) == 32)

    for m in [1, 16, 32, 256] {
        let enabled = Array(-32...32).filter { abs($0) <= m }
        assert(enabled == Array(max(-32, -m)...min(32, m)))
    }

    print("SpectrumBar: left=-32, center=0, right=32")
}
#endif
