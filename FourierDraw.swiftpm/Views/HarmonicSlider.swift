import SwiftUI

struct HarmonicSlider: View {
    @Binding var m: Int
    @Binding var isDragging: Bool
    let participating: Int

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    orderLabel
                    Spacer()
                    participatingLabel
                }

                VStack(alignment: .leading, spacing: 2) {
                    orderLabel
                    participatingLabel
                }
            }

            Slider(
                value: sliderPosition,
                in: 0...1,
                onEditingChanged: { isDragging = $0 }
            )
            .tint(vermilion)
            .frame(minHeight: 44)
            .accessibilityLabel("阶数")
            .accessibilityValue("当前 \(m)，共 \(participating) 项参与")
        }
    }

    private var orderLabel: some View {
        HStack(spacing: 0) {
            Text("阶数 |k| ≤ ")
                .foregroundStyle(ink.opacity(0.8))
            Text("\(m)")
                .foregroundStyle(vermilion)
        }
        .font(.footnote)
    }

    private var participatingLabel: some View {
        Text("共 \(participating) 项参与")
            .font(.caption)
            .foregroundStyle(ink.opacity(0.45))
    }

    private var sliderPosition: Binding<Double> {
        Binding(
            get: {
                (Double(m - 1) / 255).squareRoot()
            },
            set: { position in
                m = Int((1 + 255 * position * position).rounded())
            }
        )
    }
}
