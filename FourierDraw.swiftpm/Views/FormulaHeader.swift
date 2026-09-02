import SwiftUI

struct FormulaHeader: View {
    enum ExplanationStyle {
        case regular
        case compact
    }

    let m: Int
    let selectedCycle: Epicycle?
    let alignment: Alignment
    let explanationStyle: ExplanationStyle
    let deltaCycles: [Epicycle]
    let canvasScale: CGFloat
    let deltaShownAt: Date?

    @ScaledMetric(relativeTo: .title2) private var mainSize: CGFloat = 21
    @ScaledMetric(relativeTo: .footnote) private var scriptSize: CGFloat = 13
    @ScaledMetric(relativeTo: .footnote) private var orderSize: CGFloat = 13

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    init(
        m: Int,
        selectedCycle: Epicycle? = nil,
        mainSize: CGFloat = 21,
        scriptSize: CGFloat = 13,
        orderSize: CGFloat = 13,
        alignment: Alignment = .center,
        explanationStyle: ExplanationStyle = .regular,
        deltaCycles: [Epicycle] = [],
        canvasScale: CGFloat = 1,
        deltaShownAt: Date? = nil
    ) {
        self.m = m
        self.selectedCycle = selectedCycle
        self.alignment = alignment
        self.explanationStyle = explanationStyle
        self.deltaCycles = deltaCycles
        self.canvasScale = canvasScale
        self.deltaShownAt = deltaShownAt
        _mainSize = ScaledMetric(wrappedValue: mainSize, relativeTo: .title2)
        _scriptSize = ScaledMetric(wrappedValue: scriptSize, relativeTo: .footnote)
        _orderSize = ScaledMetric(wrappedValue: orderSize, relativeTo: .footnote)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            Group {
                if let deltaShownAt, !deltaCycles.isEmpty {
                    DeltaFormulaFeedback(
                        cycles: deltaCycles,
                        scale: canvasScale,
                        shownAt: deltaShownAt
                    )
                } else {
                    FormulaExplanation(
                        m: m,
                        style: explanationStyle
                    )
                }
            }
            .padding(.top, 24)

            SymmetryExplanation(style: explanationStyle)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
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
            .font(.system(size: orderSize, design: .serif))
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
        var main = "f(t) 等于所有绝对值不超过 \(m) 的 c k 乘 e 的 i 2πkt 次方之和。c k 表示圆有多大，e 的 i 2πkt 次方表示转多快、朝哪边转，求和符号表示把圆首尾接成一条链，绝对值 k 不超过 \(m) 表示链子只搭到第 \(m) 阶为止。两边频率对称，半径通常并不相等"
        if deltaShownAt != nil, !deltaCycles.isEmpty {
            main += "。刚加入 \(deltaCycles.count) 项，\(deltaFrequencyDescription)，\(deltaRadiusDescription)"
        }
        guard let selectedCycle else { return main }
        let unavailable = abs(selectedCycle.freq) > m
            ? "，阶数不够，这一项还没加进来"
            : ""
        return "\(main)，当前观察 k 等于 \(selectedCycle.freq)，\(details(for: selectedCycle))\(unavailable)"
    }

    private var deltaFrequencyDescription: String {
        "频率 " + deltaCycles.map { signedFrequency($0.freq) }.joined(separator: " 和 ")
    }

    private var deltaRadiusDescription: String {
        "半径 " + deltaCycles.map {
            decimal(abs($0.amp) * Double(canvasScale)) + " 点"
        }.joined(separator: " 和 ")
    }

    private func signedFrequency(_ frequency: Int) -> String {
        frequency >= 0 ? "+\(frequency)" : "−\(abs(frequency))"
    }
}

extension FormulaHeader {
    struct DeviationReadout: View {
        let deviation: Double
        let previousDeviation: Double?
        let deltaShownAt: Date?

        @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 12
        @ScaledMetric(relativeTo: .title) private var valueSize: CGFloat = 26
        @ScaledMetric(relativeTo: .title3) private var arrowSize: CGFloat = 20
        @ScaledMetric(relativeTo: .caption) private var hintSize: CGFloat = 11

        private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
        private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

        init(
            deviation: Double,
            previousDeviation: Double? = nil,
            deltaShownAt: Date? = nil
        ) {
            self.deviation = deviation
            self.previousDeviation = previousDeviation
            self.deltaShownAt = deltaShownAt
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("墨迹与原稿的平均偏离")
                    .font(.system(size: labelSize))
                    .foregroundStyle(ink.opacity(0.5))

                valueLine

                Text("阶数每加一阶，这个数不会变大")
                    .font(.system(size: hintSize))
                    .foregroundStyle(ink.opacity(0.42))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }

        @ViewBuilder
        private var valueLine: some View {
            if let previousDeviation, deltaShownAt != nil {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(verbatim: valueText(previousDeviation))
                        .foregroundStyle(ink.opacity(0.35))
                    Text(verbatim: "  →  ")
                        .font(.system(size: arrowSize, design: .serif))
                        .foregroundStyle(ink.opacity(0.4))
                    Text(verbatim: "\(valueText(deviation)) pt")
                        .foregroundStyle(vermilion)
                }
                .font(.system(size: valueSize, design: .serif))
            } else {
                Text(verbatim: "\(valueText(deviation)) pt")
                    .font(.system(size: valueSize, design: .serif))
                    .foregroundStyle(ink.opacity(0.9))
            }
        }

        private var accessibilityLabel: String {
            let current = valueText(deviation)
            if let previousDeviation, deltaShownAt != nil {
                return "墨迹与原稿的平均偏离，从 \(valueText(previousDeviation)) 点变为 \(current) 点。阶数每加一阶，这个数不会变大"
            }
            return "墨迹与原稿的平均偏离 \(current) 点。阶数每加一阶，这个数不会变大"
        }

        private func valueText(_ value: Double) -> String {
            value.formatted(.number.precision(.fractionLength(1)))
        }
    }
}

private struct DeltaFormulaFeedback: View {
    let cycles: [Epicycle]
    let scale: CGFloat
    let shownAt: Date

    @ScaledMetric(relativeTo: .footnote) private var detailSize: CGFloat = 11

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        countLabel
                        Text(frequencyDescription)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        countLabel
                        Text(frequencyDescription)
                    }
                }
                .font(.system(size: detailSize + 2, design: .serif))
                .foregroundStyle(ink.opacity(0.8))

                Text(radiusDescription)
                    .font(.system(size: detailSize))
                    .foregroundStyle(ink.opacity(0.6))
            }
            .opacity(deltaHighlightOpacity(at: timeline.date, shownAt: shownAt))
        }
    }

    private var countLabel: some View {
        Text(verbatim: "+\(cycles.count) 项")
            .foregroundStyle(vermilion)
    }

    private var frequencyDescription: String {
        cycles.map { "k = \(signedFrequency($0.freq))" }
            .joined(separator: " 和 ")
    }

    private var radiusDescription: String {
        "半径 " + cycles.map {
            radiusText(abs($0.amp) * Double(scale)) + " pt"
        }.joined(separator: " 与 ")
    }

    private func signedFrequency(_ frequency: Int) -> String {
        frequency >= 0 ? "+\(frequency)" : "−\(abs(frequency))"
    }

    private func radiusText(_ radius: Double) -> String {
        radius.formatted(.number.precision(.fractionLength(1)))
    }
}

private struct SymmetryExplanation: View {
    @ScaledMetric(relativeTo: .caption) private var fontSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption) private var topPadding: CGFloat = 8

    private let style: FormulaHeader.ExplanationStyle
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)

    init(style: FormulaHeader.ExplanationStyle) {
        self.style = style
    }

    var body: some View {
        Text("两边频率对称，半径通常并不相等")
            .font(.system(size: fontSize))
            .foregroundStyle(ink.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, style == .compact ? topPadding * 0.75 : topPadding)
    }
}

private struct FormulaExplanation: View {
    let m: Int

    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var meaningSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var symbolColumnWidth: CGFloat = 106

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)

    init(m: Int, style: FormulaHeader.ExplanationStyle) {
        self.m = m

        let symbolSize: CGFloat = style == .compact ? 11 : 15
        let meaningSize: CGFloat = style == .compact ? 11 : 13
        let rowHeight: CGFloat = style == .compact ? 22 : 28
        _symbolSize = ScaledMetric(wrappedValue: symbolSize, relativeTo: .body)
        _meaningSize = ScaledMetric(wrappedValue: meaningSize, relativeTo: .footnote)
        _rowHeight = ScaledMetric(wrappedValue: rowHeight, relativeTo: .body)
        _symbolColumnWidth = ScaledMetric(wrappedValue: 106, relativeTo: .body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            explanationRow(
                symbol: coefficientSymbol,
                meaning: "这个圆有多大"
            )
            explanationRow(
                symbol: rotationSymbol,
                meaning: "转多快、朝哪边转"
            )
            explanationRow(
                symbol: Text(verbatim: "Σ"),
                meaning: "把它们首尾接成一条链"
            )
            explanationRow(
                symbol: Text(verbatim: "|k| ≤ \(m)"),
                meaning: "链子只搭到第 \(m) 阶为止"
            )
        }
    }

    private func explanationRow(
        symbol: Text,
        meaning: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            symbol
                .font(.system(size: symbolSize, design: .serif))
                .foregroundStyle(ink.opacity(0.9))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: symbolColumnWidth, alignment: .leading)

            Text(meaning)
                .font(.system(size: meaningSize))
                .foregroundStyle(ink.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: rowHeight, alignment: .topLeading)
    }

    private var coefficientSymbol: Text {
        Text(verbatim: "c")
            + Text(verbatim: "k")
                .font(.system(size: symbolSize * 0.72, design: .serif))
                .baselineOffset(-symbolSize * 0.28)
    }

    private var rotationSymbol: Text {
        Text(verbatim: "e")
            + Text(verbatim: "i2πkt")
                .font(.system(size: symbolSize * 0.72, design: .serif))
                .baselineOffset(symbolSize * 0.48)
    }
}
