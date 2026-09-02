import SwiftUI

struct FormulaHeader: View {
    let m: Int

    @ScaledMetric(relativeTo: .title2) private var mainSize = 21.0
    @ScaledMetric(relativeTo: .footnote) private var scriptSize = 13.0

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
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
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("f(t) 等于所有绝对值不超过 \(m) 的 c k 乘 e 的 i 2πkt 次方之和")
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
}
