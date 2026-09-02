import Foundation
import CoreGraphics

struct Epicycle {
    let freq: Int
    let amp: Double
    let phase: Double
}

func dft(_ points: [CGPoint]) -> [Epicycle] {
    let count = points.count
    guard count > 0 else { return [] }

    let values = points.map {
        Complex(re: Double($0.x), im: Double($0.y))
    }
    let scale = Double(count)
    var cycles: [Epicycle] = []
    cycles.reserveCapacity(count)

    for k in 0..<count {
        var coefficient = Complex.zero

        for j in 0..<count {
            let theta = -2 * Double.pi * Double(k) * Double(j) / scale
            coefficient += values[j] * Complex.exp(theta)
        }

        coefficient /= scale
        let frequency = k < count / 2 ? k : k - count
        cycles.append(Epicycle(
            freq: frequency,
            amp: coefficient.magnitude,
            phase: coefficient.phase
        ))
    }

    return cycles.sorted {
        let lhsMagnitude = abs($0.freq)
        let rhsMagnitude = abs($1.freq)
        return lhsMagnitude == rhsMagnitude
            ? $0.freq > $1.freq
            : lhsMagnitude < rhsMagnitude
    }
}

#if DEBUG
extension Epicycle {
    static func validateDFT() {
        let count = 512
        let counterclockwise = (0..<count).map { n in
            let theta = 2 * Double.pi * Double(n) / Double(count)
            return CGPoint(x: 100 * cos(theta), y: 100 * sin(theta))
        }
        let clockwise = (0..<count).map { n in
            let theta = 2 * Double.pi * Double(n) / Double(count)
            return CGPoint(x: 100 * cos(theta), y: -100 * sin(theta))
        }

        let counterclockwiseCycles = dft(counterclockwise)
        let clockwiseCycles = dft(clockwise)
        let largestCounterclockwise = counterclockwiseCycles
            .sorted { $0.amp > $1.amp }
            .prefix(3)
            .map { (freq: $0.freq, amp: $0.amp) }
        let largestClockwise = clockwiseCycles
            .sorted { $0.amp > $1.amp }
            .prefix(3)
            .map { (freq: $0.freq, amp: $0.amp) }

        print("DFT A. counterclockwise top 3 = \(largestCounterclockwise)")
        print("DFT B. clockwise top 3 = \(largestClockwise)")
        print(
            "DFT C. counts = \(counterclockwiseCycles.filter { abs($0.freq) <= 1 }.count), "
                + "\(counterclockwiseCycles.filter { abs($0.freq) <= 128 }.count), "
                + "\(counterclockwiseCycles.filter { abs($0.freq) <= 256 }.count); "
                + "first 8 = \(counterclockwiseCycles.prefix(8).map(\.freq))"
        )
    }
}
#endif
