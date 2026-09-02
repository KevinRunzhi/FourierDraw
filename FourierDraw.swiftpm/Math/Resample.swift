import Foundation
import CoreGraphics

func closePath(_ pts: [CGPoint]) -> [CGPoint] {
    guard let first = pts.first else { return pts }
    return pts + [first]
}

func resample(_ pts: [CGPoint], to n: Int) -> [CGPoint] {
    guard n > 0 else { return [] }
    guard pts.count >= 2 else { return pts }

    var cumulative = [0.0]
    cumulative.reserveCapacity(pts.count)

    for i in 1..<pts.count {
        let dx = Double(pts[i].x - pts[i - 1].x)
        let dy = Double(pts[i].y - pts[i - 1].y)
        cumulative.append(cumulative[i - 1] + hypot(dx, dy))
    }

    guard let total = cumulative.last else { return [] }
    guard total != 0 else {
        return Array(repeating: pts[0], count: n)
    }

    var result: [CGPoint] = []
    result.reserveCapacity(n)
    var j = 1

    for i in 0..<n {
        let target = total * Double(i) / Double(n)

        while j < cumulative.count - 1 && cumulative[j] <= target {
            j += 1
        }

        let segmentLength = cumulative[j] - cumulative[j - 1]
        let t = segmentLength == 0 ? 0 : (target - cumulative[j - 1]) / segmentLength
        let start = pts[j - 1]
        let end = pts[j]

        result.append(CGPoint(
            x: start.x + (end.x - start.x) * CGFloat(t),
            y: start.y + (end.y - start.y) * CGFloat(t)
        ))
    }

    return result
}

func normalize(_ pts: [CGPoint]) -> [CGPoint] {
    guard !pts.isEmpty else { return pts }

    let count = CGFloat(pts.count)
    let centroidX = pts.reduce(0) { $0 + $1.x } / count
    let centroidY = pts.reduce(0) { $0 + $1.y } / count
    return pts.map {
        CGPoint(x: $0.x - centroidX, y: $0.y - centroidY)
    }
}

#if DEBUG
func validateResampleUtilities() {
    let sampled = resample(closePath([
        CGPoint(x: 0, y: 0),
        CGPoint(x: 100, y: 0)
    ]), to: 5)
    print("A. resample x = \(sampled.map(\.x))")

    let normalized = normalize([
        CGPoint(x: 0, y: 0),
        CGPoint(x: 2, y: 0),
        CGPoint(x: 2, y: 2),
        CGPoint(x: 0, y: 2)
    ])
    let centroidX = normalized.reduce(0) { $0 + $1.x } / CGFloat(normalized.count)
    let centroidY = normalized.reduce(0) { $0 + $1.y } / CGFloat(normalized.count)
    print("B. normalize points = \(normalized), centroid = (\(centroidX), \(centroidY))")

    let degenerate = resample([
        CGPoint(x: 1, y: 1),
        CGPoint(x: 1, y: 1)
    ], to: 512)
    print("C. degenerate resample count = \(degenerate.count)")
}
#endif
