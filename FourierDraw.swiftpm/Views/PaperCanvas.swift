import SwiftUI
import Foundation

func toScreen(_ p: CGPoint, center: CGPoint, scale: CGFloat) -> CGPoint {
    CGPoint(
        x: center.x + p.x * scale,
        y: center.y - p.y * scale
    )
}

func toMath(_ p: CGPoint, center: CGPoint, scale: CGFloat) -> CGPoint {
    CGPoint(
        x: (p.x - center.x) / scale,
        y: (center.y - p.y) / scale
    )
}

func paperScale(for extent: CGFloat, in size: CGSize) -> CGFloat {
    guard extent > 0 else { return 1 }
    return min(size.width, size.height) * 0.36 / extent
}

struct PaperCanvas: View {
    let cycles: [Epicycle]
    let ghost: [CGPoint]
    let trail: [CGPoint]
    let m: Int
    let startDate: Date
    let scale: CGFloat
    let trailOpacity: Double

    var body: some View {
        let activeCycles = cycles.filter { abs($0.freq) <= m }

        PaperCanvasTimeline(
            cycles: activeCycles,
            ghost: ghost,
            trail: trail,
            scale: scale,
            startDate: startDate,
            trailOpacity: trailOpacity
        )
        .background(PaperPalette.paper)
    }
}

private struct PaperCanvasTimeline: View {
    let cycles: [Epicycle]
    let ghost: [CGPoint]
    let trail: [CGPoint]
    let scale: CGFloat
    let startDate: Date
    let trailOpacity: Double

    private let period = 6.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let t = (elapsed / period).truncatingRemainder(dividingBy: 1)

            PaperCanvasFrame(
                cycles: cycles,
                ghost: ghost,
                trail: trail,
                t: t,
                scale: scale,
                trailOpacity: trailOpacity
            )
        }
    }
}

private struct PaperCanvasFrame: View {
    let cycles: [Epicycle]
    let ghost: [CGPoint]
    let trail: [CGPoint]
    let t: Double
    let scale: CGFloat
    let trailOpacity: Double

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width / 2, y: size.height / 2)
            let visibleTrailCount = min(
                trail.count,
                max(0, Int(t * Double(trail.count)))
            )

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(PaperPalette.paper)
            )
            drawGhost(in: &context, origin: origin)
            let penTip = drawCycles(in: &context, size: size, origin: origin)
            drawTrail(
                in: &context,
                origin: origin,
                visibleCount: visibleTrailCount
            )
            drawPenTip(penTip, in: &context, origin: origin)
        }
    }

    private func drawGhost(in context: inout GraphicsContext, origin: CGPoint) {
        guard let first = ghost.first else { return }

        var path = Path()
        path.move(to: toScreen(first, center: origin, scale: scale))
        for point in ghost.dropFirst() {
            path.addLine(to: toScreen(point, center: origin, scale: scale))
        }
        path.closeSubpath()

        context.stroke(
            path,
            with: .color(PaperPalette.ink.opacity(0.13)),
            style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
        )
    }

    private func drawCycles(
        in context: inout GraphicsContext,
        size: CGSize,
        origin: CGPoint
    ) -> CGPoint {
        var center = CGPoint.zero
        var drawnCount = 0

        for (index, cycle) in cycles.enumerated() {
            let angle = 2 * Double.pi * Double(cycle.freq) * t + cycle.phase
            let next = CGPoint(
                x: center.x + CGFloat(cycle.amp * cos(angle)),
                y: center.y + CGFloat(cycle.amp * sin(angle))
            )
            let radius = CGFloat(cycle.amp) * scale

            if radius >= 0.5 && drawnCount < 120 {
                let screenCenter = toScreen(center, center: origin, scale: scale)
                let screenNext = toScreen(next, center: origin, scale: scale)
                var ringOpacity = max(0.12, 0.30 * pow(0.985, Double(index)))
                if size.height < 700 && index >= cycles.count - 2 {
                    ringOpacity *= 0.6
                }

                let ring = Path(
                    ellipseIn: CGRect(
                        x: screenCenter.x - radius,
                        y: screenCenter.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
                context.stroke(
                    ring,
                    with: .color(PaperPalette.graphite.opacity(ringOpacity)),
                    lineWidth: 1
                )

                var rod = Path()
                rod.move(to: screenCenter)
                rod.addLine(to: screenNext)
                context.stroke(
                    rod,
                    with: .color(PaperPalette.graphite.opacity(0.42)),
                    lineWidth: 1
                )
                drawnCount += 1
            }

            center = next
        }

        return center
    }

    private func drawTrail(
        in context: inout GraphicsContext,
        origin: CGPoint,
        visibleCount: Int
    ) {
        guard visibleCount > 0 else { return }

        var path = Path()
        path.move(to: toScreen(trail[0], center: origin, scale: scale))
        for point in trail.prefix(visibleCount).dropFirst() {
            path.addLine(to: toScreen(point, center: origin, scale: scale))
        }

        context.stroke(
            path,
            with: .color(PaperPalette.ink.opacity(0.92 * trailOpacity)),
            style: StrokeStyle(
                lineWidth: 2.2,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func drawPenTip(
        _ penTip: CGPoint,
        in context: inout GraphicsContext,
        origin: CGPoint
    ) {
        let point = toScreen(penTip, center: origin, scale: scale)
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
            with: .color(PaperPalette.ink.opacity(trailOpacity))
        )
    }
}

private enum PaperPalette {
    static let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    static let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    static let graphite = Color(red: 125 / 255, green: 122 / 255, blue: 115 / 255)
}
