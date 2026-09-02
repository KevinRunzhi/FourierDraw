import SwiftUI
import Foundation

private let ghostFadeDuration = 0.4
private let circleBloomDelay = 0.003
private let circleBloomDuration = 0.35
private let cycleFadeDuration = 0.3
private let wetInkDuration = 0.5
private let sealSize = 18.0
private let sealInset = 24.0
private let annotationMinimumHeight = 560.0
private let annotationFontSize = 12.0
private let annotationInset = 12.0
private let annotationGap = 12.0
private let directionArcMinimumRadius = 26.0
private let directionArcInset = 8.0
private let directionArcSpan = Double.pi * 54 / 180
private let directionArrowSize = 6.0

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
    let previousTrail: [CGPoint]
    let deltaAddedFreqs: [Int]
    let deltaShownAt: Date?
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
        previousTrail: [CGPoint] = [],
        deltaAddedFreqs: [Int] = [],
        deltaShownAt: Date? = nil,
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
        self.previousTrail = previousTrail
        self.deltaAddedFreqs = deltaAddedFreqs
        self.deltaShownAt = deltaShownAt
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
            previousTrail: previousTrail,
            deltaAddedFreqs: deltaAddedFreqs,
            deltaShownAt: deltaShownAt,
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
    let previousTrail: [CGPoint]
    let deltaAddedFreqs: [Int]
    let deltaShownAt: Date?
    let onFrame: (Date, Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 60.0,
                paused: reduceMotion && deltaShownAt == nil
            )
        ) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let phase = reduceMotion
                ? PhaseState(stage: .draw, progress: 1, drawProgress: 1)
                : phaseState(
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
                activeDrawDuration: reduceMotion ? drawDuration : activeDrawDuration,
                scale: scale,
                trailOpacity: trailOpacity,
                reduceMotion: reduceMotion,
                maximumVisibleCycles: maximumVisibleCycles,
                usesWetInk: usesWetInk,
                highlightedFrequency: highlightedFrequency,
                previousTrail: previousTrail,
                deltaAddedFreqs: deltaAddedFreqs,
                deltaShownAt: deltaShownAt,
                renderDate: timeline.date
            )
            .onChange(of: timeline.date) {
                if !reduceMotion {
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
    let previousTrail: [CGPoint]
    let deltaAddedFreqs: [Int]
    let deltaShownAt: Date?
    let renderDate: Date

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
            drawPreviousTrail(in: &context, origin: origin)
            let cycleDrawing = drawCycles(
                in: &context,
                size: size,
                origin: origin
            )
            drawTrail(
                in: &context,
                origin: origin,
                visibleCount: visibleTrailCount
            )
            drawAnnotations(
                for: cycleDrawing.visibleCycles,
                in: &context,
                size: size,
                origin: origin
            )
            drawPenTip(cycleDrawing.penTip, in: &context, origin: origin)
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
            style: StrokeStyle(lineWidth: 1.3, dash: [5, 3.5])
        )
    }

    private var ghostOpacity: Double {
        guard phase.stage == .bloom else { return 0.34 }
        let elapsed = phase.progress * bloomDuration
        let fade = min(max(elapsed / ghostFadeDuration, 0), 1)
        return 1 - 0.66 * fade
    }

    private func drawCycles(
        in context: inout GraphicsContext,
        size: CGSize,
        origin: CGPoint
    ) -> CycleDrawing {
        var center = CGPoint.zero
        var drawnCount = 0
        var visibleCycles: [VisibleCycle] = []
        visibleCycles.reserveCapacity(min(cycles.count, maximumVisibleCycles + 1))

        for cycle in cycles {
            let angle = 2 * Double.pi * Double(cycle.freq) * phase.drawProgress
                + cycle.phase
            let fullRadius = CGFloat(cycle.amp) * scale
            let isHighlighted = cycle.freq == highlightedFrequency
            let isDeltaAdded = deltaAddedFreqs.contains(cycle.freq)
            let isDrawable = fullRadius > 0
                && (isDeltaAdded || (
                    fullRadius >= 0.5
                        && (drawnCount < maximumVisibleCycles || isHighlighted)
                ))
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
                if isDeltaAdded && deltaOpacity > 0 {
                    context.stroke(
                        ring,
                        with: .color(PaperPalette.vermilion.opacity(
                            0.95 * deltaOpacity * cycleOpacity(from: 1)
                        )),
                        lineWidth: 1.6
                    )
                }

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

                let visibleCycle = VisibleCycle(
                    frequency: cycle.freq,
                    angle: angle,
                    center: screenCenter,
                    end: screenNext,
                    radius: radius
                )
                visibleCycles.append(visibleCycle)
                drawDirectionArc(
                    for: visibleCycle,
                    in: &context
                )
                drawnCount += 1
            }

            center = next
        }

        return CycleDrawing(penTip: center, visibleCycles: visibleCycles)
    }

    private func drawDirectionArc(
        for cycle: VisibleCycle,
        in context: inout GraphicsContext
    ) {
        guard cycle.radius > directionArcMinimumRadius,
              cycle.frequency != 0 else { return }

        // Mathematical angles increase counterclockwise. toScreen flips y for the
        // downward screen axis, so +k still appears counterclockwise and -k clockwise.
        let direction = cycle.frequency > 0 ? 1.0 : -1.0
        let startAngle = cycle.angle - direction * directionArcSpan / 2
        let arcRadius = cycle.radius + directionArcInset
        let stepCount = 12
        var points: [CGPoint] = []
        points.reserveCapacity(stepCount + 1)

        for step in 0...stepCount {
            let progress = Double(step) / Double(stepCount)
            let angle = startAngle + direction * directionArcSpan * progress
            points.append(screenPoint(
                center: cycle.center,
                radius: arcRadius,
                angle: angle
            ))
        }

        guard let first = points.first,
              let previous = points.dropLast().last,
              let tip = points.last else { return }

        var arc = Path()
        arc.move(to: first)
        for point in points.dropFirst() {
            arc.addLine(to: point)
        }

        let opacity = cycleOpacity(from: 0.6)
        context.stroke(
            arc,
            with: .color(PaperPalette.graphite.opacity(opacity)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round)
        )

        let tangent = unitVector(from: previous, to: tip)
        let perpendicular = CGPoint(x: -tangent.y, y: tangent.x)
        let base = CGPoint(
            x: tip.x - tangent.x * directionArrowSize,
            y: tip.y - tangent.y * directionArrowSize
        )
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(
            x: base.x + perpendicular.x * directionArrowSize / 2,
            y: base.y + perpendicular.y * directionArrowSize / 2
        ))
        arrow.addLine(to: CGPoint(
            x: base.x - perpendicular.x * directionArrowSize / 2,
            y: base.y - perpendicular.y * directionArrowSize / 2
        ))
        arrow.closeSubpath()
        context.fill(
            arrow,
            with: .color(PaperPalette.graphite.opacity(opacity))
        )
    }

    private func drawAnnotations(
        for visibleCycles: [VisibleCycle],
        in context: inout GraphicsContext,
        size: CGSize,
        origin: CGPoint
    ) {
        guard size.height >= annotationMinimumHeight,
              let largestCycle = visibleCycles.max(by: { $0.radius < $1.radius }),
              let lastCycle = visibleCycles.last,
              let ghostBounds = ghostBounds(origin: origin) else { return }

        let rotationAnchor = screenPoint(
            center: largestCycle.center,
            radius: largestCycle.radius,
            angle: largestCycle.angle + Double.pi * 5 / 6
        )
        let annotations = [
            CanvasAnnotation(
                text: "cₖ 半径",
                anchor: midpoint(largestCycle.center, largestCycle.end),
                regions: [.left, .top, .bottom]
            ),
            CanvasAnnotation(
                text: "e^(i2πkt) 转速与方向",
                anchor: rotationAnchor,
                regions: [.top, .bottom, .left]
            ),
            CanvasAnnotation(
                text: "Σ 把这些圆首尾接起来",
                anchor: midpoint(lastCycle.center, lastCycle.end),
                regions: [.bottom, .left, .top]
            )
        ]
        let visibleBounds = CGRect(origin: .zero, size: size)
            .insetBy(dx: annotationInset, dy: annotationInset)
        var occupied: [CGRect] = []

        for annotation in annotations {
            var text = context.resolve(
                Text(annotation.text).font(.system(size: annotationFontSize))
            )
            text.shading = .color(
                PaperPalette.ink.opacity(0.78 * annotationStageOpacity)
            )
            let measured = text.measure(in: visibleBounds.size)
            let textSize = CGSize(
                width: ceil(measured.width),
                height: ceil(measured.height)
            )
            let candidates = annotation.regions.map {
                annotationRect(
                    in: $0,
                    textSize: textSize,
                    anchor: annotation.anchor,
                    ghostBounds: ghostBounds,
                    visibleBounds: visibleBounds
                )
            }
            let isAvailable: (CGRect) -> Bool = { candidate in
                visibleBounds.contains(candidate)
                    && !candidate.intersects(ghostBounds)
                    && !occupied.contains(where: { occupiedRect in
                        candidate.intersects(occupiedRect)
                    })
            }
            let preferred = candidates.first.flatMap {
                isAvailable($0) ? $0 : nil
            }
            let fallback = candidates.dropFirst().filter(isAvailable).min {
                distance(from: $0, to: annotation.anchor)
                    < distance(from: $1, to: annotation.anchor)
            }
            guard let rect = preferred ?? fallback else { continue }

            drawLeader(
                from: rect,
                to: annotation.anchor,
                in: &context
            )
            context.draw(text, at: rect.origin, anchor: .topLeading)
            occupied.append(rect.insetBy(dx: -4, dy: -4))
        }
    }

    private var annotationStageOpacity: Double {
        cycleOpacity(from: 1)
    }

    private func ghostBounds(origin: CGPoint) -> CGRect? {
        guard let first = ghost.first else { return nil }
        let firstScreenPoint = toScreen(first, center: origin, scale: scale)
        return ghost.dropFirst().reduce(
            CGRect(origin: firstScreenPoint, size: .zero)
        ) { bounds, point in
            bounds.union(CGRect(
                origin: toScreen(point, center: origin, scale: scale),
                size: .zero
            ))
        }
    }

    private func annotationRect(
        in region: AnnotationRegion,
        textSize: CGSize,
        anchor: CGPoint,
        ghostBounds: CGRect,
        visibleBounds: CGRect
    ) -> CGRect {
        let origin: CGPoint
        switch region {
        case .left:
            origin = CGPoint(
                x: ghostBounds.minX - annotationGap - textSize.width,
                y: clamped(
                    anchor.y - textSize.height / 2,
                    from: visibleBounds.minY,
                    through: visibleBounds.maxY - textSize.height
                )
            )
        case .top:
            origin = CGPoint(
                x: clamped(
                    anchor.x - textSize.width / 2,
                    from: visibleBounds.minX,
                    through: visibleBounds.maxX - textSize.width
                ),
                y: ghostBounds.minY - annotationGap - textSize.height
            )
        case .bottom:
            origin = CGPoint(
                x: clamped(
                    anchor.x - textSize.width / 2,
                    from: visibleBounds.minX,
                    through: visibleBounds.maxX - textSize.width
                ),
                y: ghostBounds.maxY + annotationGap
            )
        }
        return CGRect(origin: origin, size: textSize)
    }

    private func drawLeader(
        from rect: CGRect,
        to anchor: CGPoint,
        in context: inout GraphicsContext
    ) {
        let start = CGPoint(
            x: clamped(anchor.x, from: rect.minX, through: rect.maxX),
            y: clamped(anchor.y, from: rect.minY, through: rect.maxY)
        )
        var leader = Path()
        leader.move(to: start)
        leader.addLine(to: anchor)
        context.stroke(
            leader,
            with: .color(
                PaperPalette.ink.opacity(0.26 * annotationStageOpacity)
            ),
            lineWidth: 1
        )
        context.fill(
            Path(ellipseIn: CGRect(
                x: anchor.x - 1.9,
                y: anchor.y - 1.9,
                width: 3.8,
                height: 3.8
            )),
            with: .color(
                PaperPalette.ink.opacity(0.78 * annotationStageOpacity)
            )
        )
    }

    private func screenPoint(
        center: CGPoint,
        radius: CGFloat,
        angle: Double
    ) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y - radius * CGFloat(sin(angle))
        )
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    private func unitVector(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 0.0001)
        return CGPoint(x: dx / length, y: dy / length)
    }

    private func clamped(
        _ value: CGFloat,
        from lowerBound: CGFloat,
        through upperBound: CGFloat
    ) -> CGFloat {
        min(max(value, lowerBound), max(lowerBound, upperBound))
    }

    private func distance(from rect: CGRect, to point: CGPoint) -> CGFloat {
        hypot(rect.midX - point.x, rect.midY - point.y)
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

    private func drawPreviousTrail(
        in context: inout GraphicsContext,
        origin: CGPoint
    ) {
        guard deltaOpacity > 0, let first = previousTrail.first else { return }

        var path = Path()
        path.move(to: toScreen(first, center: origin, scale: scale))
        for point in previousTrail.dropFirst() {
            path.addLine(to: toScreen(point, center: origin, scale: scale))
        }
        context.stroke(
            path,
            with: .color(PaperPalette.ink.opacity(0.09 * deltaOpacity)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )
    }

    private var deltaOpacity: Double {
        deltaHighlightOpacity(at: renderDate, shownAt: deltaShownAt)
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

private struct CycleDrawing {
    let penTip: CGPoint
    let visibleCycles: [VisibleCycle]
}

private struct VisibleCycle {
    let frequency: Int
    let angle: Double
    let center: CGPoint
    let end: CGPoint
    let radius: CGFloat
}

private struct CanvasAnnotation {
    let text: String
    let anchor: CGPoint
    let regions: [AnnotationRegion]
}

private enum AnnotationRegion {
    case left
    case top
    case bottom
}

private enum PaperPalette {
    static let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    static let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    static let graphite = Color(red: 125 / 255, green: 122 / 255, blue: 115 / 255)
    static let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)
}
