import SwiftUI

struct HarmonicSlider: View {
    @Binding var m: Int
    let participating: Int

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 0) {
                    Text("阶数 |k| ≤ ")
                        .foregroundStyle(ink.opacity(0.8))
                    Text("\(m)")
                        .foregroundStyle(vermilion)
                }

                Spacer()

                Text("共 \(participating) 项参与")
                    .font(.system(size: 11))
                    .foregroundStyle(ink.opacity(0.45))
            }
            .font(.system(size: 13))

            Slider(value: sliderPosition, in: 0...1)
                .tint(vermilion)
                .accessibilityLabel("傅里叶阶数")
                .accessibilityValue("\(m)，共 \(participating) 项参与")
        }
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
