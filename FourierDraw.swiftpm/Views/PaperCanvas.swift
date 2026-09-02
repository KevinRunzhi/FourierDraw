import SwiftUI
import Foundation

private let ghostFadeDuration = 0.4
private let circleBloomDelay = 0.003
private let circleBloomDuration = 0.35
private let cycleFadeDuration = 0.3
private let wetInkDuration = 0.5
private let sealSize = 18.0
private let sealInset = 24.0

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
    let isFirstRound: Bool
    let hasBloom: Bool
    let isDragging: Bool
    let perfTier: PerfTier
    let highlightedFrequency: Int?
    let onFrame: (Date, Bool) -> Void

    init(
        cycles: [Epicycle],
        ghost: [CGPoint],
        trail: [CGPoint],
        m: Int,
        startDate: Date,
        scale: CGFloat,
        trailOpacity: Double,
        isFirstRound: Bool = false,
        hasBloom: Bool = false,
        isDragging: Bool = false,
        perfTier: PerfTier = .high,
        highlightedFrequency: Int? = nil,
        onFrame: @escaping (Date, Bool) -> Void = { _, _ in }
    ) {
        self.cycles = cycles
        self.ghost = ghost
        self.trail = trail
        self.m = m
        self.startDate = startDate
        self.scale = scale
        self.trailOpacity = trailOpacity
        self.isFirstRound = isFirstRound
        self.hasBloom = hasBloom
        self.isDragging = isDragging
        self.perfTier = perfTier
        self.highlightedFrequency = highlightedFrequency
        self.onFrame = onFrame
    }

    var body: some View {
        let activeCycles = cycles.filter { abs($0.freq) <= m }

        PaperCanvasTimeline(
            cycles: activeCycles,
            ghost: ghost,
            trail: trail,
            scale: scale,
            startDate: startDate,
            trailOpacity: trailOpacity,
            isFirstRound: isFirstRound,
            hasBloom: hasBloom,
            isDragging: isDragging,
            maximumVisibleCycles: perfTier.maximumVisibleCycles,
            usesWetInk: perfTier.usesWetInk,
            highlightedFrequency: highlightedFrequency,
            onFrame: onFrame
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
    let isFirstRound: Bool
    let hasBloom: Bool
    let isDragging: Bool
    let maximumVisibleCycles: Int
    let usesWetInk: Bool
    let highlightedFrequency: Int?
    let onFrame: (Date, Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if reduceMotion {
            PaperCanvasFrame(
                cycles: cycles,
                ghost: ghost,
                trail: trail,
                phase: PhaseState(stage: .draw, progress: 1, drawProgress: 1),
                activeDrawDuration: drawDuration,
                scale: scale,
                trailOpacity: trailOpacity,
                reduceMotion: true,
                maximumVisibleCycles: maximumVisibleCycles,
                usesWetInk: usesWetInk,
                highlightedFrequency: highlightedFrequency
            )
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                let phase = phaseState(
                    elapsed: elapsed,
                    isFirstRound: isFirstRound,
                    hasBloom: hasBloom,
                    isDragging: isDragging
                )
                let firstBloomDuration = isFirstRound && hasBloom ? bloomDuration : 0
                let firstDrawEnd = firstBloomDuration
                    + (isFirstRound ? firstRoundDrawDuration : drawDuration)
                let activeDrawDuration = isFirstRound && elapsed < firstDrawEnd
                    ? firstRoundDrawDuration
                    : drawDuration

                PaperCanvasFrame(
                    cycles: cycles,
                    ghost: ghost,
                    trail: trail,
                    phase: phase,
                    activeDrawDuration: activeDrawDuration,
                    scale: scale,
                    trailOpacity: trailOpacity,
                    reduceMotion: false,
                    maximumVisibleCycles: maximumVisibleCycles,
                    usesWetInk: usesWetInk,
                    highlightedFrequency: highlightedFrequency
                )
                .onChange(of: timeline.date) {
                    onFrame(Date(), phase.stage == .bloom)
                }
            }
        }
    }
}

private struct PaperCanvasFrame: View {
    let cycles: [Epicycle]
    let ghost: [CGPoint]
    let trail: [CGPoint]
    let phase: PhaseState
    let activeDrawDuration: Double
    let scale: CGFloat
    let trailOpacity: Double
    let reduceMotion: Bool
    let maximumVisibleCycles: Int
    let usesWetInk: Bool
    let highlightedFrequency: Int?

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width / 2, y: size.height / 2)
            let visibleTrailCount = min(
                trail.count,
                max(0, Int(phase.drawProgress * Double(trail.count)))
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
            drawSeal(in: &context, size: size)
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
            with: .color(PaperPalette.graphite.opacity(ghostOpacity)),
            style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
        )
    }

    private var ghostOpacity: Double {
        guard phase.stage == .bloom else { return 0.12 }
        let elapsed = phase.progress * bloomDuration
        let fade = min(max(elapsed / ghostFadeDuration, 0), 1)
        return 1 - 0.88 * fade
    }

    private func drawCycles(
        in context: inout GraphicsContext,
        size: CGSize,
        origin: CGPoint
    ) -> CGPoint {
        var center = CGPoint.zero
        var drawnCount = 0

        for cycle in cycles {
            let angle = 2 * Double.pi * Double(cycle.freq) * phase.drawProgress
                + cycle.phase
            let fullRadius = CGFloat(cycle.amp) * scale
            let isHighlighted = cycle.freq == highlightedFrequency
            let isDrawable = fullRadius >= 0.5
                && (drawnCount < maximumVisibleCycles || isHighlighted)
            let bloomScale = cycleBloomScale(for: drawnCount)
            let next = CGPoint(
                x: center.x + CGFloat(cycle.amp * bloomScale * cos(angle)),
                y: center.y + CGFloat(cycle.amp * bloomScale * sin(angle))
            )
            let radius = fullRadius * bloomScale

            if isDrawable && radius > 0 {
                let screenCenter = toScreen(center, center: origin, scale: scale)
                let screenNext = toScreen(next, center: origin, scale: scale)
                var ringOpacity = isHighlighted
                    ? 0.9
                    : max(0.12, 0.30 * pow(0.985, Double(drawnCount)))
                if size.height < 700 && drawnCount >= maximumVisibleCycles - 2 {
                    ringOpacity *= 0.6
                }
                ringOpacity = cycleOpacity(from: ringOpacity)

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
                    with: .color(
                        isHighlighted
                            ? PaperPalette.vermilion.opacity(ringOpacity)
                            : PaperPalette.graphite.opacity(ringOpacity)
                    ),
                    lineWidth: isHighlighted ? 2.5 : 1
                )

                var rod = Path()
                rod.move(to: screenCenter)
                rod.addLine(to: screenNext)
                context.stroke(
                    rod,
                    with: .color(
                        PaperPalette.graphite.opacity(cycleOpacity(from: 0.42))
                    ),
                    lineWidth: 1
                )
                drawnCount += 1
            }

            center = next
        }

        return center
    }

    private func cycleBloomScale(for index: Int) -> CGFloat {
        guard phase.stage == .bloom else { return 1 }
        let elapsed = phase.progress * bloomDuration
        let delayed = (elapsed - Double(index) * circleBloomDelay)
            / circleBloomDuration
        let progress = min(max(delayed, 0), 1)
        return CGFloat(1 - pow(1 - progress, 3))
    }

    private func cycleOpacity(from base: Double) -> Double {
        switch phase.stage {
        case .bloom, .draw:
            return base
        case .seal:
            let elapsed = phase.progress * sealDuration
            let fade = min(max(elapsed / cycleFadeDuration, 0), 1)
            return base + (0.04 - base) * fade
        case .turn:
            return 0.04 + (base - 0.04) * phase.progress
        }
    }

    private func drawTrail(
        in context: inout GraphicsContext,
        origin: CGPoint,
        visibleCount: Int
    ) {
        guard visibleCount > 0 else { return }

        let inkOpacity = trailStageOpacity * trailOpacity
        guard inkOpacity > 0 else { return }

        if phase.stage == .draw && !reduceMotion && usesWetInk {
            drawWetTrail(
                in: &context,
                origin: origin,
                visibleCount: visibleCount,
                inkOpacity: inkOpacity
            )
        } else {
            drawTrailPath(
                in: &context,
                origin: origin,
                range: 0..<visibleCount,
                lineWidth: 2,
                opacity: 0.9 * inkOpacity
            )
        }
    }

    private func drawWetTrail(
        in context: inout GraphicsContext,
        origin: CGPoint,
        visibleCount: Int,
        inkOpacity: Double
    ) {
        let pointsPerSecond = Double(trail.count) / activeDrawDuration
        let wetSegmentCount = min(
            max(0, visibleCount - 1),
            Int((wetInkDuration * pointsPerSecond).rounded(.up))
        )
        let wetStart = max(0, visibleCount - wetSegmentCount - 1)

        if wetStart > 0 {
            drawTrailPath(
                in: &context,
                origin: origin,
                range: 0..<(wetStart + 1),
                lineWidth: 2,
                opacity: 0.9 * inkOpacity
            )
        }

        guard wetStart + 1 < visibleCount else { return }
        for index in (wetStart + 1)..<visibleCount {
            let age = Double(visibleCount - 1 - index) / pointsPerSecond
            let settled = min(max(age / wetInkDuration, 0), 1)
            let lineWidth = 2.7 + (2.0 - 2.7) * settled
            let opacity = (1.0 + (0.9 - 1.0) * settled) * inkOpacity

            drawTrailPath(
                in: &context,
                origin: origin,
                range: (index - 1)..<(index + 1),
                lineWidth: lineWidth,
                opacity: opacity
            )
        }
    }

    private func drawTrailPath(
        in context: inout GraphicsContext,
        origin: CGPoint,
        range: Range<Int>,
        lineWidth: Double,
        opacity: Double
    ) {
        guard let firstIndex = range.first else { return }

        var path = Path()
        path.move(to: toScreen(trail[firstIndex], center: origin, scale: scale))
        for index in range.dropFirst() {
            path.addLine(to: toScreen(trail[index], center: origin, scale: scale))
        }

        context.stroke(
            path,
            with: .color(PaperPalette.ink.opacity(opacity)),
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private var trailStageOpacity: Double {
        switch phase.stage {
        case .bloom:
            return 0
        case .draw, .seal:
            return 1
        case .turn:
            return 1 - phase.progress
        }
    }

    private func drawPenTip(
        _ penTip: CGPoint,
        in context: inout GraphicsContext,
        origin: CGPoint
    ) {
        guard phase.stage == .draw && !reduceMotion else { return }
        let point = toScreen(penTip, center: origin, scale: scale)
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
            with: .color(PaperPalette.ink.opacity(trailOpacity))
        )
    }

    private func drawSeal(in context: inout GraphicsContext, size: CGSize) {
        let opacity: Double
        switch phase.stage {
        case .seal:
            opacity = 0.85 * phase.progress
        case .turn:
            opacity = 0.85 * (1 - phase.progress)
        case .bloom, .draw:
            return
        }

        let rect = CGRect(
            x: size.width - sealInset - sealSize,
            y: size.height - sealInset - sealSize,
            width: sealSize,
            height: sealSize
        )
        var seal = Path()
        seal.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: 3, height: 3)
        )
        context.stroke(
            seal,
            with: .color(PaperPalette.vermilion.opacity(opacity)),
            lineWidth: 1.5
        )
    }
}

private enum PaperPalette {
    static let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    static let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    static let graphite = Color(red: 125 / 255, green: 122 / 255, blue: 115 / 255)
    static let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)
}
