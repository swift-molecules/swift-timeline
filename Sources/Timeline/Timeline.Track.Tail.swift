extension Timeline.Track {
    /// The open last step of a track: from the last keyframe on, the value runs toward `value` by a progress that
    /// is a function of the time elapsed since that keyframe alone, and never ends.
    ///
    /// The progress is passed to the track's interpolation as it comes, from the last keyframe's value to `value`.
    public struct Tail {
        /// The value the tail runs toward.
        public var value: Value

        /// The progress from the last keyframe's value toward ``value`` after an elapsed time, in the units the
        /// instants are in.
        public let progress: @Sendable (_ elapsed: Scalar) -> Scalar

        public init(toward value: Value, _ progress: @escaping @Sendable (_ elapsed: Scalar) -> Scalar) {
            self.value = value
            self.progress = progress
        }
    }
}

extension Timeline.Track.Tail: Sendable where Value: Sendable {}

extension Timeline.Track.Tail where Scalar: Exponential.`Protocol` & Trigonometry.Circular {
    /// A spring released toward the value: the progress of ``Timeline/Easing/spring(_:velocity:)``, which is a
    /// function of elapsed time alone. A damped spring settles on the value; one without damping swings about it
    /// for ever.
    public static func spring(toward value: Value, _ spring: Spring<Scalar>, velocity: Scalar = 0) -> Self {
        let easing = Timeline.Easing<Scalar>.spring(spring, velocity: velocity)
        return Self(toward: value) { elapsed in easing.progress(elapsed, elapsed) }
    }

    /// The spring tail of a spring with a natural frequency and a damping ratio, for numbers written in source:
    /// where `Spring(frequency:ratio:)` would throw, it traps.
    public static func spring(toward value: Value, frequency: Scalar, ratio: Scalar, velocity: Scalar = 0) -> Self {
        let easing = Timeline.Easing<Scalar>.spring(frequency: frequency, ratio: ratio, velocity: velocity)
        return Self(toward: value) { elapsed in easing.progress(elapsed, elapsed) }
    }
}
