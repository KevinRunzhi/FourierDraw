import SwiftUI
import Foundation

enum PerfTier: Equatable {
    case high
    case low

    var maximumVisibleCycles: Int {
        self == .high ? 120 : 60
    }

    var trailResolution: Int {
        self == .high ? 1024 : 512
    }

    var usesWetInk: Bool {
        self == .high
    }
}

final class PerfTierMonitor {
    private static let warmupFrameCount = 10
    private static let measuredIntervalCount = 30
    private static let highTierThreshold = 0.0167
    private static let resizeAreaMultiplier = 1.5
    private static let resizeSettlingDuration = 0.3

    private(set) var tier = PerfTier.high

    private var isInitialMeasurementComplete = false
    private var didRemeasure = false
    private var baselineArea: CGFloat?
    private var lastSize: CGSize?
    private var lastSizeChangeDate: Date?
    private var warmupFrames = 0
    private var previousFrameDate: Date?
    private var measuredIntervals: [TimeInterval] = []

    func recordFrame(
        at date: Date,
        size: CGSize,
        isBlooming: Bool
    ) -> PerfTier? {
        let area = size.width * size.height
        guard area > 0 else { return nil }

        if size != lastSize {
            lastSize = size
            lastSizeChangeDate = date
            if isInitialMeasurementComplete {
                resetSamples()
            }
        }

        if !isInitialMeasurementComplete {
            guard !isBlooming else {
                resetSamples()
                return nil
            }

            guard let result = recordSample(at: date) else { return nil }
            tier = result
            baselineArea = area
            isInitialMeasurementComplete = true
            resetSamples()
            return result
        }

        guard tier == .high,
              !didRemeasure,
              let baselineArea,
              area > baselineArea * Self.resizeAreaMultiplier,
              let lastSizeChangeDate,
              date.timeIntervalSince(lastSizeChangeDate)
                >= Self.resizeSettlingDuration else {
            resetSamples()
            return nil
        }

        guard let result = recordSample(at: date) else { return nil }
        didRemeasure = true
        if result == .low {
            tier = .low
        }
        resetSamples()
        return tier
    }

    private func recordSample(at date: Date) -> PerfTier? {
        if warmupFrames < Self.warmupFrameCount {
            warmupFrames += 1
            previousFrameDate = date
            return nil
        }

        guard let previousFrameDate else {
            self.previousFrameDate = date
            return nil
        }

        let interval = date.timeIntervalSince(previousFrameDate)
        guard interval >= 0 else {
            resetSamples()
            return nil
        }

        self.previousFrameDate = date
        measuredIntervals.append(interval)
        guard measuredIntervals.count == Self.measuredIntervalCount else {
            return nil
        }

        let sortedIntervals = measuredIntervals.sorted()
        let rank = Int(ceil(0.9 * Double(sortedIntervals.count)))
        let p90 = sortedIntervals[rank - 1]
        return p90 <= Self.highTierThreshold ? .high : .low
    }

    private func resetSamples() {
        warmupFrames = 0
        previousFrameDate = nil
        measuredIntervals.removeAll(keepingCapacity: true)
    }
}

#if DEBUG
func debugValidatePerfTier() {
    func measuredTier(intervals: [TimeInterval]) -> PerfTier? {
        let monitor = PerfTierMonitor()
        let size = CGSize(width: 100, height: 100)
        var date = Date(timeIntervalSinceReferenceDate: 0)

        for frame in 0..<10 {
            _ = monitor.recordFrame(at: date, size: size, isBlooming: false)
            if frame < 9 {
                date = date.addingTimeInterval(0.001)
            }
        }

        var result: PerfTier?
        for interval in intervals {
            date = date.addingTimeInterval(interval)
            result = monitor.recordFrame(
                at: date,
                size: size,
                isBlooming: false
            ) ?? result
        }
        return result
    }

    let size = CGSize(width: 100, height: 100)
    let high = PerfTierMonitor()
    var date = Date(timeIntervalSinceReferenceDate: 0)
    var result: PerfTier?

    for _ in 0..<40 {
        result = high.recordFrame(at: date, size: size, isBlooming: false) ?? result
        date = date.addingTimeInterval(0.016)
    }
    assert(result == .high)

    let low = PerfTierMonitor()
    date = Date(timeIntervalSinceReferenceDate: 0)
    result = nil
    for _ in 0..<40 {
        result = low.recordFrame(at: date, size: size, isBlooming: false) ?? result
        date = date.addingTimeInterval(0.018)
    }
    assert(result == .low)

    let highP90 = measuredTier(
        intervals: Array(repeating: 0.016, count: 27)
            + Array(repeating: 0.02, count: 3)
    )
    let lowP90 = measuredTier(
        intervals: Array(repeating: 0.016, count: 26)
            + Array(repeating: 0.02, count: 4)
    )
    assert(highP90 == .high)
    assert(lowP90 == .low)

    let resize = PerfTierMonitor()
    date = Date(timeIntervalSinceReferenceDate: 0)
    for _ in 0..<40 {
        _ = resize.recordFrame(at: date, size: size, isBlooming: false)
        date = date.addingTimeInterval(0.016)
    }

    let thresholdSize = CGSize(width: 150, height: 100)
    for _ in 0..<40 {
        _ = resize.recordFrame(
            at: date,
            size: thresholdSize,
            isBlooming: false
        )
        date = date.addingTimeInterval(0.018)
    }
    assert(resize.tier == .high)

    let largerSize = CGSize(width: 123, height: 123)
    _ = resize.recordFrame(at: date, size: largerSize, isBlooming: false)
    let beforeSettling = resize.recordFrame(
        at: date.addingTimeInterval(0.299),
        size: largerSize,
        isBlooming: false
    )
    assert(beforeSettling == nil)
    date = date.addingTimeInterval(0.3)
    result = nil
    for _ in 0..<40 {
        result = resize.recordFrame(
            at: date,
            size: largerSize,
            isBlooming: false
        ) ?? result
        date = date.addingTimeInterval(0.018)
    }
    assert(result == .low)

    let lockedTier = resize.tier
    for _ in 0..<40 {
        _ = resize.recordFrame(
            at: date,
            size: CGSize(width: 200, height: 200),
            isBlooming: false
        )
        date = date.addingTimeInterval(0.016)
    }
    assert(resize.tier == lockedTier)

    print(
        "PerfTier: high=\(PerfTier.high.trailResolution), "
            + "low=\(PerfTier.low.trailResolution), resize=\(resize.tier)"
    )
}
#endif
