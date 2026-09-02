import SwiftUI
import Foundation

struct ContentView: View {
    private static let preset = makeStarPreset()
    private let m = 256

    @State private var cycles: [Epicycle]
    @State private var ghost: [CGPoint]
    @State private var trail: [CGPoint]
    @State private var ghostExtent: CGFloat
    @State private var drawingPoints: [CGPoint] = []
    @State private var trailOpacity = 1.0
    @State private var startDate = Date()

    init() {
        _cycles = State(initialValue: Self.preset.cycles)
        _ghost = State(initialValue: Self.preset.ghost)
        _trail = State(initialValue: Self.preset.trail)
        _ghostExtent = State(initialValue: Self.preset.extent)
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = paperScale(for: ghostExtent, in: geometry.size)

            ZStack {
                PaperCanvas(
                    cycles: cycles,
                    ghost: ghost,
                    trail: trail,
                    m: m,
                    startDate: startDate,
                    scale: scale,
                    trailOpacity: trailOpacity
                )

                DrawingLayer(
                    points: $drawingPoints,
                    onDrawingBegan: beginDrawing,
                    onDrawingEnded: { points in
                        finishDrawing(points, in: geometry.size, scale: scale)
                    }
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
#if DEBUG
            validateResampleUtilities()
            Epicycle.validateDFT()
            TrailCache.validateTrailCache()
#endif
        }
    }

    private func beginDrawing() {
        withAnimation(.easeOut(duration: 0.2)) {
            trailOpacity = 0.15
        }
    }

    private func finishDrawing(
        _ screenPoints: [CGPoint],
        in size: CGSize,
        scale: CGFloat
    ) {
        guard screenPoints.count >= 10 else {
            withAnimation(.easeOut(duration: 0.2)) {
                trailOpacity = 1
            }
            return
        }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let mathematicalPoints = screenPoints.map {
            toMath($0, center: center, scale: scale)
        }
        let closedPoints = closePath(mathematicalPoints)
        let resampledPoints = resample(closedPoints, to: 512)
        let normalizedPoints = normalize(resampledPoints)
        let newCycles = dft(normalizedPoints)
        let cache = TrailCache(cycles: newCycles, resolution: 512)
        cache.setM(m)

        cycles = newCycles
        ghost = normalizedPoints
        trail = cache.points()
        ghostExtent = Self.maximumExtent(of: normalizedPoints)
        trailOpacity = 1
        startDate = Date()
    }

    private static func makeStarPreset() -> StarPreset {
        let vertices = [
            CGPoint(x: 0, y: 140),
            CGPoint(x: -35.267, y: 48.541),
            CGPoint(x: -133.148, y: 43.262),
            CGPoint(x: -57.063, y: -18.541),
            CGPoint(x: -82.290, y: -113.262),
            CGPoint(x: 0, y: -60),
            CGPoint(x: 82.290, y: -113.262),
            CGPoint(x: 57.063, y: -18.541),
            CGPoint(x: 133.148, y: 43.262),
            CGPoint(x: 35.267, y: 48.541)
        ]
        let ghost = resample(closePath(vertices), to: 512)
        let cycles = dft(ghost)
        let cache = TrailCache(cycles: cycles, resolution: 512)
        cache.setM(256)
        return StarPreset(
            cycles: cycles,
            ghost: ghost,
            trail: cache.points(),
            extent: maximumExtent(of: ghost)
        )
    }

    private static func maximumExtent(of points: [CGPoint]) -> CGFloat {
        points.reduce(0) { extent, point in
            max(extent, abs(point.x), abs(point.y))
        }
    }
}

private struct StarPreset {
    let cycles: [Epicycle]
    let ghost: [CGPoint]
    let trail: [CGPoint]
    let extent: CGFloat
}
