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
