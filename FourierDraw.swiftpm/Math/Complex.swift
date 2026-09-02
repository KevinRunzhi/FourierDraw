import Foundation

struct Complex {
    var re: Double
    var im: Double

    static let zero = Complex(re: 0, im: 0)

    var magnitude: Double {
        hypot(re, im)
    }

    var phase: Double {
        atan2(im, re)
    }

    static func exp(_ theta: Double) -> Complex {
        Complex(re: cos(theta), im: sin(theta))
    }

    static func + (lhs: Complex, rhs: Complex) -> Complex {
        Complex(re: lhs.re + rhs.re, im: lhs.im + rhs.im)
    }

    static func - (lhs: Complex, rhs: Complex) -> Complex {
        Complex(re: lhs.re - rhs.re, im: lhs.im - rhs.im)
    }

    static func * (lhs: Complex, rhs: Complex) -> Complex {
        Complex(
            re: lhs.re * rhs.re - lhs.im * rhs.im,
            im: lhs.re * rhs.im + lhs.im * rhs.re
        )
    }

    static func / (lhs: Complex, rhs: Double) -> Complex {
        Complex(re: lhs.re / rhs, im: lhs.im / rhs)
    }

    static func += (lhs: inout Complex, rhs: Complex) {
        lhs = lhs + rhs
    }

    static func /= (lhs: inout Complex, rhs: Double) {
        lhs = lhs / rhs
    }
}
