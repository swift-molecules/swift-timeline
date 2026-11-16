extension Timeline.Track {
    public struct Keyframe {
        public var time: Rational
        public var value: Value
        public var easing: Easing<Scalar>

        public init(at time: Rational, _ value: Value, easing: Easing<Scalar> = .linear) {
            self.time = time
            self.value = value
            self.easing = easing
        }
    }
}

extension Timeline.Track.Keyframe: Sendable where Value: Sendable {}
