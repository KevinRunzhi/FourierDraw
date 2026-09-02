import SwiftUI

let deltaHighlightDuration = 0.9

func deltaHighlightOpacity(at date: Date, shownAt: Date?) -> Double {
    guard let shownAt else { return 0 }
    let elapsed = max(0, date.timeIntervalSince(shownAt))
    guard elapsed < deltaHighlightDuration else { return 0 }
    return elapsed <= 0.6 ? 1 : (deltaHighlightDuration - elapsed) / 0.3
}

struct ContentView: View {
    private static let initialPreset = preparePreset(
        .star,
        m: 3,
        resolution: PerfTier.high.trailResolution
    )

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cycles: [Epicycle]
    @State private var ghost: [CGPoint]
    @State private var trail: [CGPoint]
    @State private var ghostExtent: CGFloat
    @State private var m = 3
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
    @State private var previousTrail: [CGPoint] = []
    @State private var deltaShownAt: Date?
    @State private var deltaAddedFreqs: [Int] = []
    @State private var canvasScale: CGFloat = 1
    @State private var deviation: Double
    @State private var previousDeviation: Double?
    @State private var hasDismissedCaptions = false
    @State private var showIntro = true
    @State private var introOpacity = 0.0

    private let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let idleInterval = Duration.seconds(20)

    init() {
        _cycles = State(initialValue: Self.initialPreset.cycles)
        _ghost = State(initialValue: Self.initialPreset.ghost)
        _trail = State(initialValue: Self.initialPreset.trail)
        _ghostExtent = State(initialValue: Self.initialPreset.extent)
        _deviation = State(initialValue: Self.tailDeviation(
            in: Self.initialPreset.cycles,
            m: 3
        ))
        _previousDeviation = State(initialValue: nil)
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < 500 {
                narrowLayout(in: geometry.size)
            } else if geometry.size.width < 900 {
                wideLayout(in: geometry.size)
            } else {
                regularIPadLayout(in: geometry.size)
            }
        }
        .background(paper.ignoresSafeArea())
        .onChange(of: m) {
            if deltaAddedFreqs.map({ abs($0) }).max() != m {
                clearDelta()
            }
            recordInteraction()
            rebuildTrail()
            updateDeviation()
            updateSelectedFrequencyParticipation()
            updateSquareHint()
        }
        .onChange(of: isDragging) { wasDragging, isDragging in
            if isDragging {
                recordInteraction()
                clearDelta()
            } else if wasDragging {
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
            Self.debugValidateDeltaFrequencies(in: cycles)
            Self.debugValidateDeviation(in: cycles)
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
        .task(id: deltaShownAt) {
            guard let shownAt = deltaShownAt else { return }
            let remaining = max(
                0,
                deltaHighlightDuration - Date().timeIntervalSince(shownAt)
            )
            do {
                try await Task.sleep(for: .seconds(remaining))
            } catch {
                return
            }
            guard deltaShownAt == shownAt else { return }
            clearDelta()
        }
        .overlay {
            if showIntro {
                IntroCard {
                    showIntro = false
                }
                .opacity(reduceMotion ? 1 : introOpacity)
                .onAppear {
                    if reduceMotion {
                        introOpacity = 1
                    } else {
                        withAnimation(.easeOut(duration: 0.22)) {
                            introOpacity = 1
                        }
                    }
                }
            }
        }
    }

    private func narrowLayout(in size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                canvas
                    .frame(height: max(320, size.height * 0.5))

                DrawingPrompt()
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                hairline
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                FormulaHeader(
                    m: m,
                    selectedCycle: selectedCycle,
                    explanationStyle: .compact,
                    deltaCycles: deltaCycles,
                    canvasScale: canvasScale,
                    deltaShownAt: deltaShownAt
                )
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                synchronizedSineStrip()
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
            VStack(spacing: 12) {
                canvas
                DrawingPrompt()
            }
            .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                VStack(spacing: 0) {
                    FormulaHeader(
                        m: m,
                        selectedCycle: selectedCycle,
                        deltaCycles: deltaCycles,
                        canvasScale: canvasScale,
                        deltaShownAt: deltaShownAt
                    )

                    hairline
                        .padding(.vertical, 20)

                    synchronizedSineStrip()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .frame(width: sidebarWidth)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                controlPanel
                    .padding(.horizontal, 10)
            }
        }
    }

    private func regularIPadLayout(in size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("圆迹")
                        .font(.system(size: 26))
                        .foregroundStyle(ink)

                    Text("OrbitInk")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(ink.opacity(0.45))
                }

                Text("让傅里叶重新画出你的笔迹")
                    .font(.system(size: 14))
                    .foregroundStyle(ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            hairline
                .padding(.top, 12)

            HStack(spacing: 36) {
                VStack(spacing: 8) {
                    canvas
                    DrawingPrompt(primarySize: 17, secondarySize: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 0) {
                    FormulaHeader(
                        m: m,
                        selectedCycle: selectedCycle,
                        mainSize: 34,
                        scriptSize: 18,
                        orderSize: 23,
                        alignment: .leading,
                        deltaCycles: deltaCycles,
                        canvasScale: canvasScale,
                        deltaShownAt: deltaShownAt
                    )

                    Spacer(minLength: 16)

                    synchronizedSineStrip(isExpanded: true)
                        .frame(minWidth: 240, maxWidth: .infinity)

                    Spacer(minLength: 16)

                    FormulaHeader.DeviationReadout(
                        deviation: deviation * Double(canvasScale),
                        previousDeviation: previousDeviation.map {
                            $0 * Double(canvasScale)
                        },
                        deltaShownAt: deltaShownAt
                    )
                }
                .frame(width: max(416, size.width * 0.38))
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, 16)
            .frame(maxHeight: .infinity)
        }
        .padding(24)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            IPadControlPanel(
                cycles: cycles,
                m: $m,
                isDragging: $isDragging,
                participating: participatingCount,
                selectedFrequency: selectedFrequency,
                onSelect: selectFrequency
            )
            .padding(.horizontal, 24)
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
                    previousTrail: previousTrail,
                    deltaAddedFreqs: deltaAddedFreqs,
                    deltaShownAt: deltaShownAt,
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

                if !hasDismissedCaptions {
                    FirstRunCaptions(startedAt: startDate) {
                        hasDismissedCaptions = true
                    }
                    .transition(.opacity)
                }

                PresetMenu(
                    selectedPreset: $selectedPreset,
                    onSelect: selectPreset,
                    onInteraction: recordInteraction
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
            .onChange(of: scale, initial: true) { _, newScale in
                canvasScale = newScale
            }
        }
    }

    private func synchronizedSineStrip(isExpanded: Bool = false) -> some View {
        SynchronizedSineStrip(
            cycles: cycles,
            m: m,
            startDate: startDate,
            isFirstRound: isFirstRoundAfterDrawing,
            hasBloom: isFirstRoundAfterDrawing,
            isDragging: isDragging,
            selectedFrequency: selectedFrequency,
            isExpanded: isExpanded
        )
    }

    private var controlPanel: some View {
        OrderPanelContent(
            cycles: cycles,
            m: $m,
            isDragging: $isDragging,
            participating: participatingCount,
            selectedFrequency: selectedFrequency,
            showsExtendedLabels: false,
            onSelect: selectFrequency
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(height: 148)
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

    private var deltaCycles: [Epicycle] {
        cycles.filter { deltaAddedFreqs.contains($0.freq) }
    }

    private var canvasAccessibilityLabel: String {
        let subject = selectedPreset?.name ?? "手绘图形"
        let maximumRadius = Int(
            (cycles.lazy
                .filter { abs($0.freq) <= m }
                .map(\.amp)
                .max() ?? 0).rounded()
        )
        return "傅里叶重建动画，当前展示\(subject)。圆链共\(participatingCount)个圆。最大的圆半径\(maximumRadius)，代表系数 c 下标 k。圆按各自频率旋转，正频率逆时针，负频率顺时针。所有圆首尾相接，末端就是笔尖。"
    }

    private func beginDrawing() {
        recordInteraction()
        clearDelta()
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
        clearDelta()
        rebuildTrail()
        updateDeviation()
    }

    private func loadPreset(_ preset: Preset) {
        clearDelta()
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
        updateDeviation()
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

    private func updateDeviation() {
        deviation = Self.tailDeviation(in: cycles, m: m)
    }

    private func prepareDelta(oldM: Int, newM: Int) {
        let addedFrequencies = Self.deltaFrequencies(
            in: cycles,
            oldM: oldM,
            newM: newM
        )
        guard !addedFrequencies.isEmpty else {
            clearDelta()
            return
        }

        previousTrail = trail
        previousDeviation = deviation
        deltaAddedFreqs = addedFrequencies
        deltaShownAt = Date()
    }

    private func clearDelta() {
        previousTrail.removeAll(keepingCapacity: true)
        previousDeviation = nil
        deltaAddedFreqs.removeAll(keepingCapacity: true)
        deltaShownAt = nil
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
        hasDismissedCaptions = true
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

    private static func tailDeviation(in cycles: [Epicycle], m: Int) -> Double {
        sqrt(cycles.reduce(into: 0.0) { energy, cycle in
            if abs(cycle.freq) > m {
                energy += cycle.amp * cycle.amp
            }
        })
    }

    private static func deltaFrequencies(
        in cycles: [Epicycle],
        oldM: Int,
        newM: Int
    ) -> [Int] {
        cycles.compactMap { cycle in
            abs(cycle.freq) <= newM && abs(cycle.freq) > oldM
                ? cycle.freq
                : nil
        }
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

    private static func debugValidateDeltaFrequencies(in cycles: [Epicycle]) {
        let middle = deltaFrequencies(in: cycles, oldM: 3, newM: 4)
        let boundary = deltaFrequencies(in: cycles, oldM: 255, newM: 256)
        assert(middle == [4, -4])
        assert(boundary == [-256])
        print("Delta frequencies 3 -> 4: \(middle)")
        print("Delta frequencies 255 -> 256: \(boundary)")
    }

    private static func debugValidateDeviation(in cycles: [Epicycle]) {
        var previous = Double.infinity
        for order in 1...256 {
            let current = tailDeviation(in: cycles, m: order)
            assert(
                current <= previous + 1e-12,
                "Deviation increased at M=\(order)"
            )
            print("Deviation M=\(order): \(current)")
            previous = current
        }
        assert(previous < 1e-12)
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
    let isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if reduceMotion {
            SineStrip(
                cycles: cycles,
                m: m,
                t: 0,
                selectedFrequency: selectedFrequency,
                isStaticPhase: true,
                isExpanded: isExpanded
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
                    selectedFrequency: selectedFrequency,
                    isExpanded: isExpanded
                )
            }
        }
    }
}

private struct DrawingPrompt: View {
    let primarySize: CGFloat
    let secondarySize: CGFloat

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)

    init(primarySize: CGFloat = 15, secondarySize: CGFloat = 11) {
        self.primarySize = primarySize
        self.secondarySize = secondarySize
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("用手指在这里画一个封闭图形")
                .font(.system(size: primarySize))
                .foregroundStyle(ink.opacity(0.8))

            Text("虚线是你画的原稿，实线是圆链重新画出来的")
                .font(.system(size: secondarySize))
                .foregroundStyle(ink.opacity(0.45))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

private struct IPadControlPanel: View {
    let cycles: [Epicycle]
    @Binding var m: Int
    @Binding var isDragging: Bool
    let participating: Int
    let selectedFrequency: Int?
    let onSelect: (Int) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)

    var body: some View {
        OrderPanelContent(
            cycles: cycles,
            m: $m,
            isDragging: $isDragging,
            participating: participating,
            selectedFrequency: selectedFrequency,
            showsExtendedLabels: true,
            onSelect: onSelect
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 148)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color.white)
                : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .background(
            .white.opacity(reduceTransparency ? 1 : 0.78),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(ink.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct OrderPanelContent: View {
    let cycles: [Epicycle]
    @Binding var m: Int
    @Binding var isDragging: Bool
    let participating: Int
    let selectedFrequency: Int?
    let showsExtendedLabels: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            OrderPanelHeader(m: m, participating: participating)
                .frame(height: 36)

            SpectrumBar(
                cycles: cycles,
                m: m,
                selectedFrequency: selectedFrequency,
                showsExtendedLabels: showsExtendedLabels,
                onSelect: onSelect
            )
            .frame(height: 56)

            OrderPanelSlider(
                m: $m,
                isDragging: $isDragging,
                participating: participating
            )
            .frame(height: 44)
        }
    }
}

private struct OrderPanelHeader: View {
    let m: Int
    let participating: Int

    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("阶数 |k| ≤ ")
                    .foregroundStyle(ink.opacity(0.8))
                Text("\(m)")
                    .foregroundStyle(vermilion)
            }
            .font(.footnote)

            Text("共 \(participating) 项参与")
                .font(.caption)
                .foregroundStyle(ink.opacity(0.45))

            Spacer(minLength: 8)

            Text("一阶一阶看")
                .font(.system(size: 11))
                .foregroundStyle(ink.opacity(0.42))

            HStack(spacing: 12) {
                disabledStepButton(systemName: "minus", label: "降低一阶")
                disabledStepButton(systemName: "plus", label: "提高一阶")
            }
        }
    }

    private func disabledStepButton(
        systemName: String,
        label: LocalizedStringKey
    ) -> some View {
        Button(action: {}) {
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
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.35)
        .accessibilityLabel(label)
    }
}

private struct OrderPanelSlider: View {
    @Binding var m: Int
    @Binding var isDragging: Bool
    let participating: Int

    private let paper = Color(red: 241 / 255, green: 240 / 255, blue: 236 / 255)
    private let ink = Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255)
    private let vermilion = Color(red: 178 / 255, green: 53 / 255, blue: 42 / 255)
    private let thumbRadius: CGFloat = 13

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                OrderPanelSliderTrack(
                    position: Self.position(for: m),
                    isDragging: isDragging,
                    paper: paper,
                    ink: ink,
                    thumbRadius: thumbRadius
                )

                Slider(
                    value: sliderPosition,
                    in: 0...1
                )
                .tint(vermilion)
                .opacity(0.02)
                .allowsHitTesting(false)
                .accessibilityLabel("阶数")
                .accessibilityValue("当前 \(m)，共 \(participating) 项参与")
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let midpoint = geometry.size.width / 2
                        let travel = max(1, midpoint - thumbRadius)
                        let position = Double(
                            (value.location.x - midpoint) / travel
                        )
                        isDragging = true
                        m = Self.order(for: position)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }

    private var sliderPosition: Binding<Double> {
        Binding(
            get: { Self.position(for: m) },
            set: { m = Self.order(for: $0) }
        )
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
}

private struct OrderPanelSliderTrack: View {
    let position: Double
    let isDragging: Bool
    let paper: Color
    let ink: Color
    let thumbRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let midpoint = geometry.size.width / 2
            let extent = max(0, midpoint - thumbRadius) * CGFloat(position)
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

private struct PreparedPreset {
    let cycles: [Epicycle]
    let ghost: [CGPoint]
    let trail: [CGPoint]
    let extent: CGFloat
}
