import SwiftUI

struct SineStrip: View {
    let cycles: [Epicycle]
    let m: Int
    let t: Double

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        let cycle = selectedCycle
        let angle = 2 * Double.pi * Double(cycle.freq) * t + cycle.phase
        let turns = Double(cycle.freq) * t + cycle.phase / (2 * Double.pi)

        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    OrbitDiagram(angle: angle)
                        .frame(width: 44, height: 64)
                    SineWaveDiagram(turns: turns)
                        .frame(minWidth: 240, maxWidth: .infinity)
                        .frame(height: 64)
                }

                ZStack(alignment: .topLeading) {
                    SineWaveDiagram(turns: turns)
                        .frame(minWidth: 240, maxWidth: .infinity)
                        .frame(height: 64)
                    OrbitDiagram(angle: angle)
                        .frame(width: 44, height: 64)
                }
                .frame(minWidth: 240)
            }
            .frame(height: 64)

            Text(caption(for: cycle.freq))
                .font(.system(size: 11))
                .foregroundStyle(ink.opacity(0.65))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption(for: cycle.freq))
    }

    private var selectedCycle: Epicycle {
        let highestFrequency = min(max(m, 0), 32)
        var maximumAmplitude = 0.0
        var strongestByMagnitude = [Epicycle?](
            repeating: nil,
            count: highestFrequency + 1
        )

        for cycle in cycles where cycle.freq != 0 && abs(cycle.freq) <= m {
            maximumAmplitude = max(maximumAmplitude, cycle.amp)

            let magnitude = abs(cycle.freq)
            guard magnitude <= highestFrequency else { continue }
            if cycle.amp > (strongestByMagnitude[magnitude]?.amp ?? -1) {
                strongestByMagnitude[magnitude] = cycle
            }
        }

        if maximumAmplitude > 0 {
            let threshold = maximumAmplitude * 1e-3
            for magnitude in stride(from: highestFrequency, through: 1, by: -1) {
                if let cycle = strongestByMagnitude[magnitude], cycle.amp >= threshold {
                    return cycle
                }
            }
        }

        return cycles.first { $0.freq == 0 }
            ?? Epicycle(freq: 0, amp: 0, phase: 0)
    }

    private func caption(for frequency: Int) -> String {
        guard frequency != 0 else { return "k = 0 · 每周保持不转" }
        let direction = frequency > 0 ? "逆时针" : "顺时针"
        return "k = \(frequency) · 每周\(direction)转 \(abs(frequency)) 圈"
    }
}

private struct OrbitDiagram: View {
    let angle: Double

    private let graphite = Color(red: 125 / 255, green: 122 / 255, blue: 115 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        Canvas { context, size in
            let radius = 20.0
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y - radius * sin(angle)
            )

            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                ),
                with: .color(graphite.opacity(0.35)),
                lineWidth: 1
            )

            var rod = Path()
            rod.move(to: center)
            rod.addLine(to: point)
            context.stroke(
                rod,
                with: .color(graphite.opacity(0.5)),
                lineWidth: 1
            )

            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: point.x - 3,
                        y: point.y - 3,
                        width: 6,
                        height: 6
                    )
                ),
                with: .color(vermilion)
            )
        }
    }
}

private struct SineWaveDiagram: View {
    let turns: Double

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        Canvas { context, size in
            let baseline = size.height / 2
            let amplitude = min(18.0, size.height * 0.28)
            let sampleCount = max(240, Int(size.width.rounded(.up)))
            let progress = normalizedProgress(turns / 2)

            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: baseline))
            for sample in 1...sampleCount {
                let xProgress = Double(sample) / Double(sampleCount)
                wave.addLine(
                    to: CGPoint(
                        x: size.width * xProgress,
                        y: baseline - amplitude * sin(4 * Double.pi * xProgress)
                    )
                )
            }
            context.stroke(
                wave,
                with: .color(ink.opacity(0.8)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            let marker = CGPoint(
                x: size.width * progress,
                y: baseline - amplitude * sin(4 * Double.pi * progress)
            )
            var guide = Path()
            guide.move(to: CGPoint(x: marker.x, y: baseline))
            guide.addLine(to: marker)
            context.stroke(
                guide,
                with: .color(vermilion.opacity(0.3)),
                lineWidth: 1
            )
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: marker.x - 3,
                        y: marker.y - 3,
                        width: 6,
                        height: 6
                    )
                ),
                with: .color(vermilion)
            )
        }
    }

    private func normalizedProgress(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder >= 0 ? remainder : remainder + 1
    }
}
