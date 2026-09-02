import Foundation
import CoreGraphics

final class TrailCache {
    private let cyclesByFrequency: [Int: Epicycle]
    private let resolution: Int
    private let maximumM: Int
    private var currentM = -1
    private var trail: [Complex]

    init(cycles: [Epicycle], resolution: Int) {
        var cyclesByFrequency: [Int: Epicycle] = [:]
        for cycle in cycles {
            cyclesByFrequency[cycle.freq] = cycle
        }

        self.cyclesByFrequency = cyclesByFrequency
        self.resolution = max(0, resolution)
        maximumM = cycles.map { abs($0.freq) }.max() ?? 0
        trail = Array(repeating: .zero, count: max(0, resolution))
        setM(0)
    }

    func setM(_ newM: Int) {
        let targetM = min(max(0, newM), maximumM)

        if targetM > currentM {
            for m in (currentM + 1)...targetM {
                apply(m: m, direction: 1)
            }
        } else if targetM < currentM {
            for m in stride(from: currentM, to: targetM, by: -1) {
                apply(m: m, direction: -1)
            }
        }

        currentM = targetM
    }

    func points() -> [CGPoint] {
        trail.map { CGPoint(x: $0.re, y: $0.im) }
    }

    private func apply(m: Int, direction: Double) {
        if m == 0 {
            apply(frequency: 0, direction: direction)
        } else {
            apply(frequency: m, direction: direction)
            apply(frequency: -m, direction: direction)
        }
    }

    private func apply(frequency: Int, direction: Double) {
        guard let cycle = cyclesByFrequency[frequency] else { return }

        let coefficient = Complex(
            re: cycle.amp * cos(cycle.phase),
            im: cycle.amp * sin(cycle.phase)
        )

        for i in trail.indices {
            let theta = 2 * Double.pi * Double(frequency) * Double(i) / Double(resolution)
            let value = coefficient * Complex.exp(theta)
            trail[i].re += direction * value.re
            trail[i].im += direction * value.im
        }
    }
}

#if DEBUG
extension TrailCache {
    static func validateTrailCache() {
        let randomPoints = (0..<40).map { _ in
            CGPoint(
                x: Double.random(in: -100...100),
                y: Double.random(in: -100...100)
            )
        }
        let samples = normalize(resample(closePath(randomPoints), to: 512))
        let cycles = dft(samples)
        let resolution = 512
        let cache = TrailCache(cycles: cycles, resolution: resolution)

        for m in [1, 5, 60, 255, 256] {
            cache.setM(m)
            let incremental = cache.trail
            let full = fullTrail(cycles: cycles, resolution: resolution, m: m)
            let maximumError = zip(incremental, full).map {
                hypot($0.re - $1.re, $0.im - $1.im)
            }.max() ?? 0
            print("TrailCache M=\(m), max error = \(maximumError)")
        }
    }

    private static func fullTrail(
        cycles: [Epicycle],
        resolution: Int,
        m: Int
    ) -> [Complex] {
        (0..<resolution).map { i in
            var point = Complex.zero

            for cycle in cycles where abs(cycle.freq) <= m {
                let coefficient = Complex(
                    re: cycle.amp * cos(cycle.phase),
                    im: cycle.amp * sin(cycle.phase)
                )
                let theta = 2 * Double.pi * Double(cycle.freq) * Double(i)
                    / Double(resolution)
                point += coefficient * Complex.exp(theta)
            }

            return point
        }
    }
}
#endif
