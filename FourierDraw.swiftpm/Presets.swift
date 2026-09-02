import Foundation

enum Preset: String, CaseIterable, Identifiable {
    case star
    case heart
    case square

    var id: Self { self }

    var name: String {
        switch self {
        case .star: "五角星"
        case .heart: "心形"
        case .square: "正方形"
        }
    }

    var points: [CGPoint] {
        switch self {
        case .star: PresetPoints.star
        case .heart: PresetPoints.heart
        case .square: PresetPoints.square
        }
    }
}

private enum PresetPoints {
    static let star = [
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

    // Samples of x = 16sin³t, y = 13cos t − 5cos2t − 2cos3t − cos4t.
    static let heart = [
        CGPoint(x: 0.000, y: 40.000),
        CGPoint(x: 0.121, y: 41.566),
        CGPoint(x: 0.950, y: 46.086),
        CGPoint(x: 3.131, y: 53.051),
        CGPoint(x: 7.173, y: 61.676),
        CGPoint(x: 13.408, y: 70.990),
        CGPoint(x: 21.950, y: 79.944),
        CGPoint(x: 32.680, y: 87.523),
        CGPoint(x: 45.255, y: 92.853),
        CGPoint(x: 59.124, y: 95.282),
        CGPoint(x: 73.578, y: 94.436),
        CGPoint(x: 87.801, y: 90.232),
        CGPoint(x: 100.938, y: 82.865),
        CGPoint(x: 112.167, y: 72.755),
        CGPoint(x: 120.762, y: 60.477),
        CGPoint(x: 126.160, y: 46.679),
        CGPoint(x: 128.000, y: 32.000),
        CGPoint(x: 126.160, y: 17.002),
        CGPoint(x: 120.762, y: 2.120),
        CGPoint(x: 112.167, y: -12.360),
        CGPoint(x: 100.938, y: -26.297),
        CGPoint(x: 87.801, y: -39.664),
        CGPoint(x: 73.578, y: -52.508),
        CGPoint(x: 59.124, y: -64.893),
        CGPoint(x: 45.255, y: -76.853),
        CGPoint(x: 32.680, y: -88.348),
        CGPoint(x: 21.950, y: -99.245),
        CGPoint(x: 13.408, y: -109.313),
        CGPoint(x: 7.173, y: -118.245),
        CGPoint(x: 3.131, y: -125.692),
        CGPoint(x: 0.950, y: -131.310),
        CGPoint(x: 0.121, y: -134.811),
        CGPoint(x: 0.000, y: -136.000),
        CGPoint(x: -0.121, y: -134.811),
        CGPoint(x: -0.950, y: -131.310),
        CGPoint(x: -3.131, y: -125.692),
        CGPoint(x: -7.173, y: -118.245),
        CGPoint(x: -13.408, y: -109.313),
        CGPoint(x: -21.950, y: -99.245),
        CGPoint(x: -32.680, y: -88.348),
        CGPoint(x: -45.255, y: -76.853),
        CGPoint(x: -59.124, y: -64.893),
        CGPoint(x: -73.578, y: -52.508),
        CGPoint(x: -87.801, y: -39.664),
        CGPoint(x: -100.938, y: -26.297),
        CGPoint(x: -112.167, y: -12.360),
        CGPoint(x: -120.762, y: 2.120),
        CGPoint(x: -126.160, y: 17.002),
        CGPoint(x: -128.000, y: 32.000),
        CGPoint(x: -126.160, y: 46.679),
        CGPoint(x: -120.762, y: 60.477),
        CGPoint(x: -112.167, y: 72.755),
        CGPoint(x: -100.938, y: 82.865),
        CGPoint(x: -87.801, y: 90.232),
        CGPoint(x: -73.578, y: 94.436),
        CGPoint(x: -59.124, y: 95.282),
        CGPoint(x: -45.255, y: 92.853),
        CGPoint(x: -32.680, y: 87.523),
        CGPoint(x: -21.950, y: 79.944),
        CGPoint(x: -13.408, y: 70.990),
        CGPoint(x: -7.173, y: 61.676),
        CGPoint(x: -3.131, y: 53.051),
        CGPoint(x: -0.950, y: 46.086),
        CGPoint(x: -0.121, y: 41.566)
    ]

    static let square = [
        CGPoint(x: -120, y: 120),
        CGPoint(x: -120, y: -120),
        CGPoint(x: 120, y: -120),
        CGPoint(x: 120, y: 120)
    ]
}
