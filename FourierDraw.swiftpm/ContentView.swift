import SwiftUI

struct ContentView: View {
    private static let initialPreset = preparePreset(
        .star,
        m: 256,
        resolution: PerfTier.high.trailResolution
    )

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var cycles: [Epicycle]
    @State private var ghost: [CGPoint]
    @State private var trail: [CGPoint]
    @State private var ghostExtent: CGFloat
    @State private var m = 256
    @State private var isDragging = false
    @State private var isFirstRoundAfterDrawing = false
    @State private var drawingPoints: [CGPoint] = []
    @State private var trailOpacity = 1.0
    @State private var startDate = Date()
    @State private var perfTier = PerfTier.high
    @State private var perfTierMonitor = PerfTierMonitor()
    @State private var selectedPreset: Preset? = .star
    @State private var hasCompletedDrawing = false
    @State private var selectedFrequency: Int?
    @State private var selectedFrequencyWasParticipating = false
    @State private var showsSquareHint = false
    @State private var hasShownSquareHint = false
    @State private var lastInteractionDate = Date()

    private let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let idleInterval = Duration.seconds(20)

    init() {
        _cycles = State(initialValue: Self.initialPreset.cycles)
        _ghost = State(initialValue: Self.initialPreset.ghost)
        _trail = State(initialValue: Self.initialPreset.trail)
        _ghostExtent = State(initialValue: Self.initialPreset.extent)
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < 500 {
                narrowLayout(in: geometry.size)
            } else {
                wideLayout(in: geometry.size)
            }
        }
        .background(paper.ignoresSafeArea())
        .onChange(of: m) {
            recordInteraction()
            rebuildTrail()
            updateSelectedFrequencyParticipation()
            updateSquareHint()
        }
        .onChange(of: isDragging) { wasDragging, isDragging in
            if wasDragging && !isDragging {
                resumeAfterDragging()
            }
        }
        .onAppear {
#if DEBUG
            validateResampleUtilities()
            Epicycle.validateDFT()
            TrailCache.validateTrailCache()
            debugValidatePhaseState()
            debugValidatePerfTier()
            debugValidateSpectrumBar()
            assert(Self.participatingCount(in: cycles, m: 1) == 3)
            assert(Self.participatingCount(in: cycles, m: 256) == 512)
            print("ContentView: M=1 -> 3, M=256 -> 512")
            Self.debugValidateManualSelection()
            Self.debugValidatePresetSequence()
#endif
        }
        .task(id: lastInteractionDate) {
            do {
                try await Task.sleep(for: idleInterval)
            } catch {
                return
            }
            advanceIdlePreset()
        }
    }

    private func narrowLayout(in size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                canvas
                    .frame(height: max(320, size.height * 0.5))

                if !hasCompletedDrawing {
                    Text("用手指画一个封闭图形试试")
                        .font(.footnote)
                        .foregroundStyle(ink.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                hairline
                    .padding(.horizontal, 24)
                    .padding(.top, hasCompletedDrawing ? 18 : 14)

                FormulaHeader(m: m, selectedCycle: selectedCycle)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                synchronizedSineStrip
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                controlPanel
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func wideLayout(in size: CGSize) -> some View {
        let sidebarWidth = min(320, max(260, size.width * 0.36))

        return HStack(spacing: 0) {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                VStack(spacing: 0) {
                    FormulaHeader(m: m, selectedCycle: selectedCycle)

                    hairline
                        .padding(.vertical, 20)

                    synchronizedSineStrip

                    controlPanel
                        .padding(.top, 24)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .frame(width: sidebarWidth)
        }
    }

    private var canvas: some View {
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
                    trailOpacity: trailOpacity,
                    isFirstRound: isFirstRoundAfterDrawing,
                    hasBloom: isFirstRoundAfterDrawing,
                    isDragging: isDragging,
                    perfTier: perfTier,
                    highlightedFrequency: selectedFrequency,
                    onFrame: { date, isBlooming in
                        measurePerformance(
                            at: date,
                            size: geometry.size,
                            isBlooming: isBlooming
                        )
                    }
                )
                .id(selectedPreset)
                .transition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(canvasAccessibilityLabel)

                DrawingLayer(
                    points: $drawingPoints,
                    onDrawingBegan: beginDrawing,
                    onDrawingEnded: { points in
                        finishDrawing(
                            points,
                            in: geometry.size,
                            scale: scale
                        )
                    }
                )
                .accessibilityHidden(true)

                PresetMenu(
                    selectedPreset: $selectedPreset,
                    onSelect: selectPreset
                )
                .padding(12)

                if showsSquareHint {
                    Text("低阶只画得出圆滑的东西，直角是高频堆出来的")
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.52))
                        .multilineTextAlignment(.leading)
                        .padding(16)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .bottomLeading
                        )
                        .allowsHitTesting(false)
                        .accessibilityLabel("低阶只画得出圆滑的东西，直角是高频堆出来的")
                        .transition(.opacity)
                }
            }
        }
    }

    private var synchronizedSineStrip: some View {
        SynchronizedSineStrip(
            cycles: cycles,
            m: m,
            startDate: startDate,
            isFirstRound: isFirstRoundAfterDrawing,
            hasBloom: isFirstRoundAfterDrawing,
            isDragging: isDragging,
            selectedFrequency: selectedFrequency
        )
    }

    private var controlPanel: some View {
        VStack(spacing: 16) {
            SpectrumBar(
                cycles: cycles,
                m: m,
                selectedFrequency: selectedFrequency,
                onSelect: selectFrequency
            )
            .frame(height: 96)

            HarmonicSlider(
                m: $m,
                isDragging: $isDragging,
                participating: participatingCount
            )
        }
        .padding(16)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color.white)
                : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .background(
            .white.opacity(reduceTransparency ? 1 : 0.78),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(ink.opacity(0.12), lineWidth: 1)
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(ink.opacity(0.12))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private var participatingCount: Int {
        Self.participatingCount(in: cycles, m: m)
    }

    private var selectedCycle: Epicycle? {
        guard let selectedFrequency else { return nil }
        return cycles.first { $0.freq == selectedFrequency }
    }

    private var canvasAccessibilityLabel: String {
        let subject = selectedPreset?.name ?? "手绘图形"
        return "傅里叶重建动画，当前展示\(subject)"
    }

    private func beginDrawing() {
        recordInteraction()
        clearSelectedFrequency()
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
        let normalizedPoints = normalize(
            resample(closePath(mathematicalPoints), to: 512)
        )

        cycles = dft(normalizedPoints)
        ghost = normalizedPoints
        ghostExtent = Self.maximumExtent(of: normalizedPoints)
        leaveSquarePreset()
        selectedPreset = nil
        hasCompletedDrawing = true
        clearSelectedFrequency()
        trailOpacity = 1
        isFirstRoundAfterDrawing = true
        startDate = Date()
        rebuildTrail()
    }

    private func loadPreset(_ preset: Preset) {
        let isEnteringSquare = preset == .square && selectedPreset != .square
        if preset != .square {
            leaveSquarePreset()
        } else if isEnteringSquare {
            hasShownSquareHint = false
            showsSquareHint = false
        }

        let prepared = Self.preparePreset(
            preset,
            m: m,
            resolution: perfTier.trailResolution
        )
        cycles = prepared.cycles
        ghost = prepared.ghost
        trail = prepared.trail
        ghostExtent = prepared.extent
        selectedPreset = preset
        clearSelectedFrequency()
        drawingPoints.removeAll(keepingCapacity: true)
        trailOpacity = 1
        isFirstRoundAfterDrawing = false
        startDate = Date()
        updateSquareHint()
    }

    private func selectPreset(_ preset: Preset) {
        recordInteraction()
        loadPreset(preset)
    }

    private func rebuildTrail() {
        let cache = TrailCache(
            cycles: cycles,
            resolution: perfTier.trailResolution
        )
        cache.setM(m)
        trail = cache.points()
    }

    private func selectFrequency(_ frequency: Int) {
        recordInteraction()
        if selectedFrequency == frequency {
            clearSelectedFrequency()
            return
        }

        selectedFrequency = frequency
        selectedFrequencyWasParticipating = abs(frequency) <= m
    }

    private func clearSelectedFrequency() {
        selectedFrequency = nil
        selectedFrequencyWasParticipating = false
    }

    private func updateSelectedFrequencyParticipation() {
        let state = Self.selectionState(
            frequency: selectedFrequency,
            wasParticipating: selectedFrequencyWasParticipating,
            m: m
        )
        selectedFrequency = state.frequency
        selectedFrequencyWasParticipating = state.wasParticipating
    }

    private func updateSquareHint() {
        guard selectedPreset == .square else {
            showsSquareHint = false
            return
        }
        guard m <= 32 else {
            withAnimation(.easeOut(duration: 0.2)) {
                showsSquareHint = false
            }
            return
        }
        guard !hasShownSquareHint else { return }

        hasShownSquareHint = true
        withAnimation(.easeIn(duration: 0.3)) {
            showsSquareHint = true
        }
    }

    private func leaveSquarePreset() {
        hasShownSquareHint = false
        withAnimation(.easeOut(duration: 0.2)) {
            showsSquareHint = false
        }
    }

    private func recordInteraction() {
        lastInteractionDate = Date()
    }

    private func advanceIdlePreset() {
        guard let selectedPreset else { return }
        let nextPreset = Self.nextPreset(after: selectedPreset)

        withAnimation(.easeInOut(duration: 0.5)) {
            loadPreset(nextPreset)
        }
        lastInteractionDate = Date()
    }

    private func resumeAfterDragging() {
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(startDate))
        let state = phaseState(
            elapsed: elapsed,
            isFirstRound: isFirstRoundAfterDrawing,
            hasBloom: isFirstRoundAfterDrawing,
            isDragging: true
        )
        guard state.stage == .draw else { return }

        let firstBloomDuration = isFirstRoundAfterDrawing ? bloomDuration : 0
        let firstDrawEnd = firstBloomDuration
            + (isFirstRoundAfterDrawing ? firstRoundDrawDuration : drawDuration)

        if isFirstRoundAfterDrawing && elapsed < firstDrawEnd {
            let resumedElapsed = firstBloomDuration
                + state.drawProgress * firstRoundDrawDuration
            startDate = now.addingTimeInterval(-resumedElapsed)
        } else {
            isFirstRoundAfterDrawing = false
            startDate = now.addingTimeInterval(-state.drawProgress * drawDuration)
        }
    }

    private func measurePerformance(
        at date: Date,
        size: CGSize,
        isBlooming: Bool
    ) {
        guard let measuredTier = perfTierMonitor.recordFrame(
            at: date,
            size: size,
            isBlooming: isBlooming
        ), measuredTier != perfTier else { return }

        perfTier = measuredTier
        rebuildTrail()
    }

    private static func preparePreset(
        _ preset: Preset,
        m: Int,
        resolution: Int
    ) -> PreparedPreset {
        let points = normalize(resample(closePath(preset.points), to: 512))
        let cycles = dft(points)
        let cache = TrailCache(cycles: cycles, resolution: resolution)
        cache.setM(m)
        return PreparedPreset(
            cycles: cycles,
            ghost: points,
            trail: cache.points(),
            extent: maximumExtent(of: points)
        )
    }

    private static func participatingCount(in cycles: [Epicycle], m: Int) -> Int {
        cycles.count { abs($0.freq) <= m }
    }

    private static func nextPreset(after preset: Preset) -> Preset {
        switch preset {
        case .star: .heart
        case .heart: .square
        case .square: .star
        }
    }

    private static func selectionState(
        frequency: Int?,
        wasParticipating: Bool,
        m: Int
    ) -> (frequency: Int?, wasParticipating: Bool) {
        guard let frequency else { return (nil, false) }
        let isParticipating = abs(frequency) <= m
        guard !wasParticipating || isParticipating else { return (nil, false) }
        return (frequency, isParticipating)
    }

#if DEBUG
    private static func debugValidateManualSelection() {
        let removed = selectionState(frequency: 3, wasParticipating: true, m: 2)
        assert(removed.frequency == nil && !removed.wasParticipating)

        let retained = selectionState(frequency: 3, wasParticipating: false, m: 2)
        assert(retained.frequency == 3 && !retained.wasParticipating)

        let joined = selectionState(frequency: 3, wasParticipating: false, m: 3)
        assert(joined.frequency == 3 && joined.wasParticipating)
        let removedAfterJoining = selectionState(
            frequency: joined.frequency,
            wasParticipating: joined.wasParticipating,
            m: 2
        )
        assert(removedAfterJoining.frequency == nil)
        print("Manual selection: participating removal, outside retention, rejoin removal passed")
    }

    private static func debugValidatePresetSequence() {
        assert(nextPreset(after: .star) == .heart)
        assert(nextPreset(after: .heart) == .square)
        assert(nextPreset(after: .square) == .star)
        print("Idle presets: star -> heart -> square -> star")
    }
#endif

    private static func maximumExtent(of points: [CGPoint]) -> CGFloat {
        points.reduce(0) { extent, point in
            max(extent, abs(point.x), abs(point.y))
        }
    }
}

private struct SynchronizedSineStrip: View {
    let cycles: [Epicycle]
    let m: Int
    let startDate: Date
    let isFirstRound: Bool
    let hasBloom: Bool
    let isDragging: Bool
    let selectedFrequency: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if reduceMotion {
            SineStrip(
                cycles: cycles,
                m: m,
                t: 0,
                selectedFrequency: selectedFrequency,
                isStaticPhase: true
            )
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let phase = phaseState(
                    elapsed: timeline.date.timeIntervalSince(startDate),
                    isFirstRound: isFirstRound,
                    hasBloom: hasBloom,
                    isDragging: isDragging
                )
                SineStrip(
                    cycles: cycles,
                    m: m,
                    t: phase.drawProgress,
                    selectedFrequency: selectedFrequency
                )
            }
        }
    }
}

private struct PreparedPreset {
    let cycles: [Epicycle]
    let ghost: [CGPoint]
    let trail: [CGPoint]
    let extent: CGFloat
}
