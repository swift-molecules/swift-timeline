extension Timeline {
    public struct Track<Value, Scalar: BinaryFloatingPoint & Sendable> {
        public let keyframes: [Keyframe]

        public init(_ keyframes: [Keyframe]) throws(Error) {
            guard !keyframes.isEmpty else { throw .empty }
            guard zip(keyframes, keyframes.dropFirst()).allSatisfy({ $0.time < $1.time }) else { throw .order }
            self.keyframes = keyframes
        }
    }
}

extension Timeline.Track: Sendable where Value: Sendable {}

extension Timeline.Track {
    /// A track over keyframes written in order in source.
    ///
    /// No keyframes, or instants that do not strictly increase, trap. Keyframes built at run time go through
    /// ``init(_:)``, which throws.
    public init(ordered keyframes: [Keyframe]) {
        precondition(!keyframes.isEmpty, "A track has at least one keyframe")
        precondition(zip(keyframes, keyframes.dropFirst()).allSatisfy { $0.time < $1.time }, "A track's instants strictly increase")
        self.keyframes = keyframes
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
    }

    public var start: Rational { keyframes[keyframes.startIndex].time }

    public var end: Rational { keyframes[keyframes.endIndex - 1].time }

    public var duration: Rational { end - start }

    public func value<Failure: Swift::Error>(
        at time: Rational,
        interpolating interpolate: (Value, Value, Scalar) throws(Failure) -> Value
    ) throws(Failure) -> Value {
        var low = keyframes.startIndex
        var high = keyframes.endIndex
        while high - low > 1 {
            let middle = low + (high - low) / 2
            if keyframes[middle].time <= time { low = middle } else { high = middle }
        }
        let from = keyframes[low]
        guard time > from.time, high < keyframes.endIndex else { return from.value }
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
        return Timeline.Track<Result, Scalar>(ordered: result)
    }

    public func shifted(by offset: Rational) -> Self {
        Self(ordered: keyframes.map { Keyframe(at: $0.time + offset, $0.value, easing: $0.easing) })
    }

    public func stretched(by factor: Rational) throws(Error) -> Self {
        guard factor > .zero else { throw .factor }
        let start = start
        return Self(ordered: keyframes.map { Keyframe(at: start + ($0.time - start) * factor, $0.value, easing: $0.easing) })
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
        return Self(ordered: keyframes + other.shifted(by: end + gap - other.start).keyframes)
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

    /// The value at an instant on a smooth curve through the keyframes' values, ignoring their easings: a cubic
    /// through each pair of keyframes whose slope at a keyframe is that of the line through its two neighbours,
    /// or, at the first and last keyframes, through their one neighbour. Before the first keyframe and from the
    /// last on the value is the first and the last value.
    public func smooth(at time: Rational) -> Value {
        var low = keyframes.startIndex
        var high = keyframes.endIndex
        while high - low > 1 {
            let middle = low + (high - low) / 2
            if keyframes[middle].time <= time { low = middle } else { high = middle }
        }
        let from = keyframes[low]
        guard time > from.time, high < keyframes.endIndex else { return from.value }
        let to = keyframes[high]
        let span = (to.time - from.time).approximation(as: Scalar.self)
        let t = (time - from.time).approximation(as: Scalar.self) / span
        let leaving = slope(at: low) * span
        let entering = slope(at: high) * span
        let (t2, t3) = (t * t, t * t * t)
        let start = (2 * t3 - 3 * t2 + 1) * from.value + (t3 - 2 * t2 + t) * leaving
        return start + (-2 * t3 + 3 * t2) * to.value + (t3 - t2) * entering
    }

    /// The slope of the smooth curve at a keyframe.
    private func slope(at index: Int) -> Scalar {
        let low = Swift.max(index - 1, keyframes.startIndex)
        let high = Swift.min(index + 1, keyframes.endIndex - 1)
        let run = (keyframes[high].time - keyframes[low].time).approximation(as: Scalar.self)
        return (keyframes[high].value - keyframes[low].value) / run
    }

    private static func mix(_ from: Value, _ to: Value, _ progress: Scalar) -> Value {
        from + (to - from) * progress
    }
}
