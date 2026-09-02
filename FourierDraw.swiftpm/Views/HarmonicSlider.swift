import SwiftUI

struct HarmonicSlider: View {
    @Binding var m: Int
    @Binding var isDragging: Bool
    let participating: Int
    private let onIncrease: (Int, Int) -> Void

    private let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    init(
        m: Binding<Int>,
        isDragging: Binding<Bool>,
        participating: Int,
        onIncrease: @escaping (Int, Int) -> Void = { _, _ in }
    ) {
        _m = m
        _isDragging = isDragging
        self.participating = participating
        self.onIncrease = onIncrease

#if DEBUG
        _ = Self.mappingValidation
#endif
    }

    var body: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    orderLabel
                    participatingLabel
                    Spacer(minLength: 8)
                    stepControls
                }

                VStack(alignment: .leading, spacing: 4) {
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

                    stepControls
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            ZStack {
                SymmetricSliderTrack(
                    position: Self.position(for: m),
                    isDragging: isDragging,
                    paper: paper,
                    ink: ink
                )

                Slider(
                    value: sliderPosition,
                    in: 0...1,
                    onEditingChanged: { isDragging = $0 }
                )
                .tint(vermilion)
                .opacity(0.02)
                .accessibilityLabel("阶数")
                .accessibilityValue("当前 \(m)，共 \(participating) 项参与")
            }
            .frame(minHeight: 44)
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

    private var stepControls: some View {
        HStack(spacing: 16) {
            Text("一阶一阶看")
                .font(.system(size: 11))
                .foregroundStyle(ink.opacity(0.42))

            HStack(spacing: 12) {
                stepButton(
                    systemName: "minus",
                    accessibilityLabel: "降低一阶",
                    isDisabled: m <= 1,
                    action: decrease
                )
                stepButton(
                    systemName: "plus",
                    accessibilityLabel: "提高一阶",
                    isDisabled: m >= 256,
                    action: increase
                )
            }
        }
    }

    private func stepButton(
        systemName: String,
        accessibilityLabel: LocalizedStringKey,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.55))
                Circle()
                    .stroke(ink.opacity(0.22), lineWidth: 1.1)
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ink.opacity(0.6))
            }
            .frame(width: 28, height: 28)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var sliderPosition: Binding<Double> {
        Binding(
            get: { Self.position(for: m) },
            set: { position in
                m = Self.order(for: position)
            }
        )
    }

    private func decrease() {
        let newM = max(1, m - 1)
        guard newM < m else { return }
        m = Self.order(for: Self.position(for: newM))
    }

    private func increase() {
        let oldM = m
        let newM = min(256, oldM + 1)
        guard newM > oldM else { return }
        onIncrease(oldM, newM)
        m = Self.order(for: Self.position(for: newM))
    }

    private static func position(for m: Int) -> Double {
        let clampedM = min(max(m, 1), 256)
        return (Double(clampedM - 1) / 255).squareRoot()
    }

    private static func order(for position: Double) -> Int {
        let clampedPosition = min(max(position, 0), 1)
        return min(
            max(Int((1 + 255 * clampedPosition * clampedPosition).rounded()), 1),
            256
        )
    }

#if DEBUG
    private static let mappingValidation: Void = {
        var passed = 0
        for targetM in 1...256 {
            let roundTripM = order(for: position(for: targetM))
            assert(
                roundTripM == targetM,
                "HarmonicSlider mapping failed for M=\(targetM)"
            )
            passed += 1
        }
        print("HarmonicSlider inverse mapping: \(passed)/256 passed")
    }()
#endif
}

private struct SymmetricSliderTrack: View {
    let position: Double
    let isDragging: Bool
    let paper: Color
    let ink: Color

    var body: some View {
        GeometryReader { geometry in
            let midpoint = geometry.size.width / 2
            let extent = midpoint * CGFloat(position)
            let centerY = geometry.size.height / 2

            ZStack {
                Capsule()
                    .fill(ink.opacity(0.14))
                    .frame(height: 4)

                Capsule()
                    .fill(ink.opacity(0.48))
                    .frame(width: extent * 2, height: 4)
                    .position(x: midpoint, y: centerY)

                Rectangle()
                    .fill(ink.opacity(0.22))
                    .frame(width: 1, height: 18)
                    .position(x: midpoint, y: centerY)

                Circle()
                    .fill(paper)
                    .overlay {
                        Circle()
                            .stroke(ink.opacity(0.28), lineWidth: 1.2)
                    }
                    .frame(width: 14, height: 14)
                    .position(x: midpoint - extent, y: centerY)

                Circle()
                    .fill(paper)
                    .overlay {
                        Circle()
                            .stroke(ink.opacity(0.4), lineWidth: 1.5)
                    }
                    .frame(
                        width: isDragging ? 26 : 20,
                        height: isDragging ? 26 : 20
                    )
                    .position(x: midpoint + extent, y: centerY)
            }
        }
        .allowsHitTesting(false)
    }
}
