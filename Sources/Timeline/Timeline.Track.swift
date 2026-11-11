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

    internal init(ordered keyframes: [Keyframe]) { self.keyframes = keyframes }
}
