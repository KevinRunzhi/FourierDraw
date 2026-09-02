import SwiftUI

struct FormulaHeader: View {
    let m: Int
    let selectedCycle: Epicycle?

    @ScaledMetric(relativeTo: .title2) private var mainSize = 21.0
    @ScaledMetric(relativeTo: .footnote) private var scriptSize = 13.0

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    init(m: Int, selectedCycle: Epicycle? = nil) {
        self.m = m
        self.selectedCycle = selectedCycle
    }

    var body: some View {
        VStack(spacing: 0) {
            mainFormula
                .opacity(selectedCycle == nil ? 1 : 0.4)

            if let selectedCycle {
                Rectangle()
                    .fill(ink.opacity(0.12))
                    .frame(height: 1)
                    .padding(.vertical, 10)

                selectedFormula(for: selectedCycle)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.8),
            value: selectedCycle?.freq
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var mainFormula: some View {
        VStack(spacing: 2) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    formulaStart
                    formulaEnd
                }

                VStack(spacing: 0) {
                    formulaStart
                    formulaEnd
                }
            }
            .font(.system(size: mainSize, design: .serif))

            HStack(spacing: 0) {
                Text(verbatim: "|k| ≤ ")
                    .foregroundStyle(ink.opacity(0.7))
                Text(verbatim: "\(m)")
                    .foregroundStyle(vermilion)
            }
            .font(.system(size: scriptSize, design: .serif))
        }
    }

    private func selectedFormula(for cycle: Epicycle) -> some View {
        VStack(spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    selectedFormulaBase(for: cycle.freq)
                    selectedFormulaExponent(for: cycle.freq)
                        .baselineOffset(scriptSize * 0.5)
                }

                VStack(spacing: 0) {
                    selectedFormulaBase(for: cycle.freq)
                    selectedFormulaExponent(for: cycle.freq)
                }
            }
            .foregroundStyle(ink)

            Text(verbatim: details(for: cycle))
                .font(.system(size: scriptSize))
                .foregroundStyle(ink.opacity(0.7))
                .multilineTextAlignment(.center)

            if abs(cycle.freq) > m {
                Text("阶数不够，这一项还没加进来")
                    .font(.caption)
                    .foregroundStyle(ink.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func selectedFormulaBase(for frequency: Int) -> some View {
        Text(verbatim: "c\(subscriptText(frequency)) · e")
            .font(.system(size: mainSize, design: .serif))
    }

    private func selectedFormulaExponent(for frequency: Int) -> some View {
        Text(verbatim: exponent(for: frequency))
            .font(.system(size: scriptSize, design: .serif))
    }

    private var formulaStart: some View {
        HStack(spacing: 0) {
            Text(verbatim: "f(t) = Σ c")
                .foregroundStyle(ink)
            Text(verbatim: "k")
                .font(.system(size: scriptSize, design: .serif))
                .baselineOffset(-scriptSize * 0.3)
                .foregroundStyle(ink)
        }
    }

    private var formulaEnd: some View {
        HStack(spacing: 0) {
            Text(verbatim: " · e")
                .foregroundStyle(ink)
            Text(verbatim: "i2πkt")
                .font(.system(size: scriptSize, design: .serif))
                .baselineOffset(scriptSize * 0.5)
                .foregroundStyle(ink)
        }
    }

    private func exponent(for frequency: Int) -> String {
        if frequency < 0 {
            return "−i2π·\(abs(frequency))t"
        }
        return "i2π·\(frequency)t"
    }

    private func details(for cycle: Epicycle) -> String {
        let radius = decimal(cycle.amp)
        let phase = decimal(abs(cycle.phase / Double.pi) < 0.05
            ? 0
            : cycle.phase / Double.pi)
        let rotation: String
        if cycle.freq > 0 {
            rotation = "每周逆时针转 \(cycle.freq) 圈"
        } else if cycle.freq < 0 {
            rotation = "每周顺时针转 \(abs(cycle.freq)) 圈"
        } else {
            rotation = "每周保持不转"
        }
        return "半径 \(radius) · 起始角 \(phase)π · \(rotation)"
    }

    private func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(rounded)
    }

    private func subscriptText(_ value: Int) -> String {
        let digits: [Character: Character] = [
            "-": "₋", "0": "₀", "1": "₁", "2": "₂", "3": "₃",
            "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"
        ]
        return String(String(value).compactMap { digits[$0] })
    }

    private var accessibilityLabel: String {
        let main = "f(t) 等于所有绝对值不超过 \(m) 的 c k 乘 e 的 i 2πkt 次方之和"
        guard let selectedCycle else { return main }
        let unavailable = abs(selectedCycle.freq) > m
            ? "，阶数不够，这一项还没加进来"
            : ""
        return "\(main)，当前观察 k 等于 \(selectedCycle.freq)，\(details(for: selectedCycle))\(unavailable)"
    }
}
