extension Timeline {
    public struct Track<Value, Scalar: BinaryFloatingPoint & Sendable> {
        public let keyframes: [Keyframe]

        /// The open step after the last keyframe, or `nil` for a value that holds from the last keyframe on.
        public let tail: Tail?

        public init(_ keyframes: [Keyframe], tail: Tail? = nil) throws(Error) {
            guard !keyframes.isEmpty else { throw .empty }
            guard zip(keyframes, keyframes.dropFirst()).allSatisfy({ $0.time < $1.time }) else { throw .order }
            self.keyframes = keyframes
            self.tail = tail
        }
    }
}

extension Timeline.Track: Sendable where Value: Sendable {}

extension Timeline.Track {
    /// A track over keyframes written in order in source.
    ///
    /// No keyframes, or instants that do not strictly increase, trap. Keyframes built at run time go through
    /// ``init(_:)``, which throws.
    public init(ordered keyframes: [Keyframe], tail: Tail? = nil) {
        precondition(!keyframes.isEmpty, "A track has at least one keyframe")
        precondition(zip(keyframes, keyframes.dropFirst()).allSatisfy { $0.time < $1.time }, "A track's instants strictly increase")
        self.keyframes = keyframes
        self.tail = tail
    }

    /// A track through (instant, value) keys written in order in source, every segment on one easing.
    ///
    /// No keys, or instants that do not strictly increase, trap.
    public init(ordered keys: [(Rational, Value)], easing: Timeline.Easing<Scalar> = .linear) {
        self.init(ordered: keys.map { Keyframe(at: $0.0, $0.1, easing: easing) })
    }

    /// A value that jumps to each key's value at its instant and stays there until the next.
    public static func steps(_ keys: [(Rational, Value)]) -> Self {
        Self(ordered: keys, easing: .hold)
    }

    public init(constant value: Value, at time: Rational = .zero) {
        self.keyframes = [Keyframe(at: time, value)]
        self.tail = nil
    }

    /// A track that is `value` until an instant and runs on from it by a tail that never ends.
    public init(from value: Value, at time: Rational = .zero, tail: Tail) {
        self.keyframes = [Keyframe(at: time, value)]
        self.tail = tail
    }

    public var start: Rational { keyframes[keyframes.startIndex].time }

    public var end: Rational { keyframes[keyframes.endIndex - 1].time }

    public var duration: Rational { end - start }

    public func value<Failure: Swift::Error>(
        at time: Rational,
        interpolating interpolate: (Value, Value, Scalar) throws(Failure) -> Value
    ) throws(Failure) -> Value {
        let (low, high) = segment(at: time)
        let from = keyframes[low]
        guard time > from.time else { return from.value }
        guard high < keyframes.endIndex else { return try ending(at: time, interpolating: interpolate) }
        let to = keyframes[high]
        let elapsed = (time - from.time).approximation(as: Scalar.self)
        let duration = (to.time - from.time).approximation(as: Scalar.self)
        return try interpolate(from.value, to.value, from.easing.progress(elapsed, duration))
    }

    public func value<Failure: Swift::Error>(
        at time: Rational,
        looping loop: Timeline.Loop,
        interpolating interpolate: (Value, Value, Scalar) throws(Failure) -> Value
    ) throws(Failure) -> Value {
        try value(at: start + loop.time(at: time - start), interpolating: interpolate)
    }

    /// The value at an instant on a smooth curve through the keyframes' values, ignoring their easings: a cubic
    /// through each pair of keyframes whose slope at a keyframe is that of the line through its two neighbours,
    /// or, at the first and last keyframes, through their one neighbour. Before the first keyframe the value is
    /// the first value, and from the last on it is as ``value(at:interpolating:)`` gives.
    ///
    /// The curve is found by interpolation alone, so it needs nothing of a value but `interpolate`: the cubic is
    /// written as a Bézier curve whose inner control points are affine combinations of three keyframes' values,
    /// each made by two interpolations, one of them at a progress from one to three halves, and the curve is
    /// evaluated by de Casteljau at the exact fraction of the segment.
    public func smooth<Failure: Swift::Error>(
        at time: Rational,
        interpolating interpolate: (Value, Value, Scalar) throws(Failure) -> Value
    ) throws(Failure) -> Value {
        let (low, high) = segment(at: time)
        let from = keyframes[low]
        guard time > from.time else { return from.value }
        guard high < keyframes.endIndex else { return try ending(at: time, interpolating: interpolate) }
        let to = keyframes[high]
        let leaving = try control(at: low, toward: high, interpolating: interpolate)
        let entering = try control(at: high, toward: low, interpolating: interpolate)
        let t = Self.ratio(time - from.time, to.time - from.time).approximation(as: Scalar.self)
        let first = try interpolate(from.value, leaving, t)
        let middle = try interpolate(leaving, entering, t)
        let last = try interpolate(entering, to.value, t)
        return try interpolate(try interpolate(first, middle, t), try interpolate(middle, last, t), t)
    }

    /// The indices of the last keyframe at or before an instant, or the first if none is, and of the one after it,
    /// which is the end index past the last keyframe.
    private func segment(at time: Rational) -> (Int, Int) {
        var low = keyframes.startIndex
        var high = keyframes.endIndex
        while high - low > 1 {
            let middle = low + (high - low) / 2
            if keyframes[middle].time <= time { low = middle } else { high = middle }
        }
        return (low, high)
    }

    /// The value after the last keyframe: held, or run on by the tail.
    private func ending<Failure: Swift::Error>(
        at time: Rational,
        interpolating interpolate: (Value, Value, Scalar) throws(Failure) -> Value
    ) throws(Failure) -> Value {
        let last = keyframes[keyframes.endIndex - 1]
        guard let tail else { return last.value }
        return try interpolate(last.value, tail.value, tail.progress((time - last.time).approximation(as: Scalar.self)))
    }

    /// The inner control point of the smooth cubic beside the keyframe at `index` on the segment toward the
    /// keyframe at `other`: the keyframe's value moved a third of the segment along the curve's tangent there.
    ///
    /// The tangent is the line through the keyframe's neighbours, `behind` and `ahead` as seen going toward
    /// `other`, so the point is `value + share × (ahead − behind)` with share the segment over three times the
    /// neighbours' distance, less than one third inside the track and one third at its ends. It is made as
    /// `interpolate(interpolate(behind, value, 1 / (1 − share)), ahead, share)`, and at an end, where `behind` is the
    /// keyframe itself, as `interpolate(value, ahead, share)`.
    private func control<Failure: Swift::Error>(
        at index: Int,
        toward other: Int,
        interpolating interpolate: (Value, Value, Scalar) throws(Failure) -> Value
    ) throws(Failure) -> Value {
        let lower = Swift.max(index - 1, keyframes.startIndex)
        let upper = Swift.min(index + 1, keyframes.endIndex - 1)
        let (behind, ahead) = other > index ? (lower, upper) : (upper, lower)
        let span = other > index ? keyframes[other].time - keyframes[index].time : keyframes[index].time - keyframes[other].time
        let reach = 3 * (keyframes[upper].time - keyframes[lower].time)
        let share = Self.ratio(span, reach).approximation(as: Scalar.self)
        let value = keyframes[index].value
        guard behind != index else { return try interpolate(value, keyframes[ahead].value, share) }
        let lever = Self.ratio(reach, reach - span).approximation(as: Scalar.self)
        return try interpolate(try interpolate(keyframes[behind].value, value, lever), keyframes[ahead].value, share)
    }

    /// One positive time over another.
    private static func ratio(_ time: Rational, _ other: Rational) -> Rational {
        do throws(Rational.Error) {
            return try time.divided(by: other)
        } catch {
            preconditionFailure("A segment of a track is not empty")
        }
    }
}

extension Timeline.Track {
    public func map<Result, Failure: Swift::Error>(
        _ transform: (Value) throws(Failure) -> Result
    ) throws(Failure) -> Timeline.Track<Result, Scalar> {
        var result: [Timeline.Track<Result, Scalar>.Keyframe] = []
        result.reserveCapacity(keyframes.count)
        for keyframe in keyframes {
            result.append(.init(at: keyframe.time, try transform(keyframe.value), easing: keyframe.easing))
        }
        guard let tail else { return Timeline.Track<Result, Scalar>(ordered: result) }
        return Timeline.Track<Result, Scalar>(ordered: result, tail: .init(toward: try transform(tail.value), tail.progress))
    }

    public func shifted(by offset: Rational) -> Self {
        Self(ordered: keyframes.map { Keyframe(at: $0.time + offset, $0.value, easing: $0.easing) }, tail: tail)
    }

    public func stretched(by factor: Rational) throws(Error) -> Self {
        guard factor > .zero else { throw .factor }
        let start = start
        return Self(ordered: keyframes.map { Keyframe(at: start + ($0.time - start) * factor, $0.value, easing: $0.easing) }, tail: tail)
    }

    public var reversed: Self {
        let (start, end) = (start, end)
        var result: [Keyframe] = []
        result.reserveCapacity(keyframes.count)
        var leaving: Timeline.Easing<Scalar> = .linear
        keyframes.forEach { keyframe in
            result.append(Keyframe(at: start + (end - keyframe.time), keyframe.value, easing: leaving))
            leaving = keyframe.easing.reversed
        }
        result.reverse()
        return Self(ordered: result)
    }

    public func appending(_ other: Self, after gap: Rational) throws(Error) -> Self {
        guard gap > .zero else { throw .order }
        return Self(ordered: keyframes + other.shifted(by: end + gap - other.start).keyframes, tail: other.tail)
    }

    public func staggered(count: Cardinal, every interval: Rational) -> [Self] {
        var result: [Self] = []
        var offset = Rational.zero
        (0..<Int(bitPattern: count)).forEach { _ in
            result.append(shifted(by: offset))
            offset += interval
        }
        return result
    }

    /// That many copies, the first unchanged and the last shifted by `span`, the gaps between neighbours in
    /// proportion to weights drawn from a sequence, as ``Timeline/instants(_:from:to:weights:)``.
    public func staggered(count: Cardinal, over span: Rational, weights: some Swift.Sequence<Rational>) -> [Self] {
        Timeline.instants(count, from: .zero, to: span, weights: weights).map(shifted(by:))
    }
}

extension Timeline.Track where Value == Scalar {
    /// A rise from 0 to 1 that starts at an instant and lasts a positive duration, on an easing.
    public static func ramp(at start: Rational, lasting duration: Rational, easing: Timeline.Easing<Scalar> = .linear) -> Self {
        precondition(duration > .zero, "A ramp lasts a positive duration")
        return Self(ordered: [Keyframe(at: start, 0, easing: easing), Keyframe(at: start + duration, 1)])
    }

    /// Pulses that rise at once and die away: 0 until each pulse, its peak at its instant, falling to 0 over
    /// its duration on an easing, and 0 until the next. The track starts one duration before the first pulse.
    ///
    /// Each pulse lasts a positive duration and starts after the one before has died away; otherwise it
    /// traps. No pulses is 0 throughout.
    public static func pulses(
        _ pulses: [(at: Rational, peak: Scalar, lasting: Rational)],
        easing: Timeline.Easing<Scalar> = .linear
    ) -> Self {
        guard let first = pulses.first else { return Self(constant: 0) }
        var keyframes = [Keyframe(at: first.at - first.lasting, 0, easing: .hold)]
        keyframes.reserveCapacity(2 * pulses.count + 1)
        var previous: Rational?
        for pulse in pulses {
            precondition(pulse.lasting > .zero, "A pulse lasts a positive duration")
            if let previous { precondition(pulse.at > previous, "A pulse starts after the one before has died away") }
            keyframes.append(Keyframe(at: pulse.at, pulse.peak, easing: easing))
            keyframes.append(Keyframe(at: pulse.at + pulse.lasting, 0, easing: .hold))
            previous = pulse.at + pulse.lasting
        }
        return Self(ordered: keyframes)
    }

    /// The value at an instant, straight between the keyframes' values at the eased progress.
    public func value(at time: Rational) -> Value {
        value(at: time, interpolating: Self.mix)
    }

    /// The value at an instant with the loop applied from the track's start.
    public func value(at time: Rational, looping loop: Timeline.Loop) -> Value {
        value(at: time, looping: loop, interpolating: Self.mix)
    }

    /// The value at an instant on the smooth curve through the keyframes' values, mixed straight.
    public func smooth(at time: Rational) -> Value {
        smooth(at: time, interpolating: Self.mix)
    }

    private static func mix(_ from: Value, _ to: Value, _ progress: Scalar) -> Value {
        from + (to - from) * progress
    }
}
