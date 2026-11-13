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
            let easing = keyframe.easing
            result.append(Keyframe(at: start + (end - keyframe.time), keyframe.value, easing: leaving))
            leaving = Timeline.Easing { elapsed, duration in 1 - easing.progress(duration - elapsed, duration) }
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
}

extension Timeline.Track where Value == Scalar {
    /// A rise from 0 to 1 that starts at an instant and lasts a positive duration, on an easing.
    public static func ramp(at start: Rational, lasting duration: Rational, easing: Timeline.Easing<Scalar> = .linear) -> Self {
        precondition(duration > .zero, "A ramp lasts a positive duration")
        return Self(ordered: [Keyframe(at: start, 0, easing: easing), Keyframe(at: start + duration, 1)])
    }

    /// Hits that die away: 0 until each hit, its strength at its instant, falling to 0 over its duration on an
    /// easing, and 0 until the next.
    ///
    /// Each hit lasts a positive duration and starts after the one before has died away; otherwise it
    /// traps. No hits is 0 throughout.
    public static func hits(
        _ hits: [(at: Rational, strength: Scalar, lasting: Rational)],
        easing: Timeline.Easing<Scalar> = .easeOut(power: 3)
    ) -> Self {
        guard let first = hits.first else { return Self(constant: 0) }
        var keyframes = [Keyframe(at: first.at - first.lasting, 0, easing: .hold)]
        keyframes.reserveCapacity(2 * hits.count + 1)
        for (index, hit) in hits.enumerated() {
            precondition(hit.lasting > .zero, "A hit lasts a positive duration")
            keyframes.append(Keyframe(at: hit.at, hit.strength, easing: easing))
            let end = hit.at + hit.lasting
            let next = hits.index(after: index)
            if next < hits.endIndex { precondition(hits[next].at > end, "A hit starts after the one before has died away") }
            keyframes.append(Keyframe(at: end, 0, easing: .hold))
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
    /// through each pair of keyframes whose slope at a keyframe is that of the line through its two neighbours.
    ///
    /// The slope at the first and last keyframes, in value per unit of time, is `first` and `last`, or, when
    /// `nil`, that of the line to their one neighbour. Before the first keyframe and from the last on the value is
    /// the first and the last value.
    public func smooth(at time: Rational, first: Scalar? = nil, last: Scalar? = nil) -> Value {
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
        let leaving = slope(at: low, first: first, last: last) * span
        let entering = slope(at: high, first: first, last: last) * span
        let (t2, t3) = (t * t, t * t * t)
        let start = (2 * t3 - 3 * t2 + 1) * from.value + (t3 - 2 * t2 + t) * leaving
        return start + (-2 * t3 + 3 * t2) * to.value + (t3 - t2) * entering
    }

    /// The slope of the smooth curve at a keyframe.
    private func slope(at index: Int, first: Scalar?, last: Scalar?) -> Scalar {
        if index == keyframes.startIndex, let first { return first }
        if index == keyframes.endIndex - 1, let last { return last }
        let low = Swift.max(index - 1, keyframes.startIndex)
        let high = Swift.min(index + 1, keyframes.endIndex - 1)
        let run = (keyframes[high].time - keyframes[low].time).approximation(as: Scalar.self)
        return (keyframes[high].value - keyframes[low].value) / run
    }

    private static func mix(_ from: Value, _ to: Value, _ progress: Scalar) -> Value {
        from + (to - from) * progress
    }
}
