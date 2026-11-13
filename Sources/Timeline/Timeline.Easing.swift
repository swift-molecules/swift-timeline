extension Timeline {
    public struct Easing<Scalar: BinaryFloatingPoint & Sendable>: Sendable {
        public let progress: @Sendable (_ elapsed: Scalar, _ duration: Scalar) -> Scalar

        public init(_ progress: @escaping @Sendable (_ elapsed: Scalar, _ duration: Scalar) -> Scalar) {
            self.progress = progress
        }
    }
}

extension Timeline.Easing {
    public init(fraction curve: @escaping @Sendable (Scalar) -> Scalar) {
        self.progress = { elapsed, duration in curve(elapsed / duration) }
    }

    public static var linear: Self { Self(fraction: { $0 }) }

    public static var hold: Self { Self { _, _ in 0 } }

    public static func bezier(_ curve: Bezier<Point<2, Scalar>>) throws(Error) -> Self {
        let points = curve.controlPoints
        guard points.count == 4 else { throw .degree }
        guard points[0].x == 0, points[0].y == 0, points[3].x == 1, points[3].y == 1 else { throw .endpoints }
        let across = (points[1].x, points[2].x)
        let up = (points[1].y, points[2].y)
        guard across.0 >= 0, across.0 <= 1, across.1 >= 0, across.1 <= 1 else { throw .monotone }
        guard up.0.isFinite, up.1.isFinite else { throw .endpoints }
        return Self(fraction: { fraction in
            guard fraction > 0 else { return 0 }
            guard fraction < 1 else { return 1 }
            var low: Scalar = 0
            var high: Scalar = 1
            (0...Scalar.significandBitCount).forEach { _ in
                let middle = (low + high) / 2
                if Self.cubic(across.0, across.1, at: middle) < fraction { low = middle } else { high = middle }
            }
            return Self.cubic(up.0, up.1, at: (low + high) / 2)
        })
    }

    /// The cubic Bézier coordinate with end values 0 and 1 and the two control values given, by de Casteljau.
    private static func cubic(_ first: Scalar, _ second: Scalar, at parameter: Scalar) -> Scalar {
        let rest = 1 - parameter
        let start = first * parameter
        let middle = first * rest + second * parameter
        let end = second * rest + parameter
        return (start * rest + middle * parameter) * rest + (middle * rest + end * parameter) * parameter
    }
}

extension Timeline.Easing where Scalar: Exponential.`Protocol` & Trigonometry.Circular {
    public static func spring(_ spring: Spring<Scalar>, velocity: Scalar = 0) -> Self {
        let start = Spring<Scalar>.State(displacement: 1, velocity: -velocity)
        return Self { elapsed, _ in 1 - spring.displacement(at: elapsed, from: start) }
    }
}

extension Timeline.Easing {
    /// The timing curve through (0, 0), (`x1`, `y1`), (`x2`, `y2`) and (1, 1), the four numbers a cubic
    /// Bézier timing function is written with.
    ///
    /// For numbers written in source: an inner x outside 0…1 or an inner y that is not finite traps. A curve
    /// built at run time goes through ``bezier(_:)``, which throws.
    public static func bezier(_ x1: Scalar, _ y1: Scalar, _ x2: Scalar, _ y2: Scalar) -> Self {
        let curve = Bezier(start: Point(x: 0, y: 0), control1: Point(x: x1, y: y1), control2: Point(x: x2, y: y2), end: Point(x: 1, y: 1))
        do throws(Error) {
            return try bezier(curve)
        } catch {
            preconditionFailure("A timing curve's inner x lies in 0...1 and its inner y is finite")
        }
    }

    /// Level at both ends: 3u² − 2u³ of the fraction u.
    public static var smooth: Self {
        Self(fraction: { fraction in
            let u = clamped(fraction)
            return u * u * (3 - 2 * u)
        })
    }

    /// Slow to start: the fraction to a power.
    public static func easeIn(power: Int = 2) -> Self {
        precondition(power >= 1, "An easing's power is at least one")
        return Self(fraction: { fraction in raised(clamped(fraction), to: power) })
    }

    /// Quick to start, long to settle: one minus what is left of the fraction to a power.
    public static func easeOut(power: Int = 2) -> Self {
        precondition(power >= 1, "An easing's power is at least one")
        return Self(fraction: { fraction in 1 - raised(1 - clamped(fraction), to: power) })
    }

    /// Slow at both ends: ``easeIn(power:)`` over the first half and ``easeOut(power:)`` over the second.
    public static func easeInOut(power: Int = 2) -> Self {
        precondition(power >= 1, "An easing's power is at least one")
        return Self(fraction: { fraction in
            let u = clamped(fraction)
            guard u >= 1 / 2 else { return raised(2 * u, to: power) / 2 }
            return 1 - raised(2 - 2 * u, to: power) / 2
        })
    }

    /// The fraction held to 0…1.
    private static func clamped(_ fraction: Scalar) -> Scalar {
        Swift.min(Swift.max(fraction, 0), 1)
    }

    /// A value to a whole power, by multiplication alone.
    private static func raised(_ value: Scalar, to power: Int) -> Scalar {
        var result: Scalar = 1
        (0..<power).forEach { _ in result *= value }
        return result
    }
}
