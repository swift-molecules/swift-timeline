extension Timeline {
    /// Weights that stray from one by keyed random draws: the gaps of an uneven stagger that is the same on every
    /// run with one key.
    ///
    /// The weight at an index is `1 + spread × (2s − 1024) / 1024`, exactly, where `s` is the top ten bits of the
    /// first word of `Threefry.block(key: key, counter: Threefry.Block(index, stream))`: the draw
    /// `Threefry.unit(key:stream:index:)` taken down to a multiple of 1/1024 and counted in 1024ths. So it lies
    /// from `1 − spread` up to, not including, `1 + spread`. As a sequence the weights are those at indices 1, 2,
    /// 3 and on, without end: the weight of the gap before the event numbered `k`, counting the first event as 0,
    /// is the weight at `k`.
    public struct Jitter: Hashable, Sendable {
        public let key: Threefry.Key

        /// How far a weight may stray from one either way: 0 for equal weights, 1/2 for weights from one half to
        /// three halves.
        public let spread: Rational

        /// The Threefry stream the draws are taken from.
        public let stream: UInt64

        /// Weights under a key with a spread from 0 to 1, which keeps every weight from going negative.
        ///
        /// For numbers written in source: a spread outside 0…1 traps.
        public init(key: Threefry.Key, spread: Rational, stream: UInt64 = 0) {
            precondition(spread >= .zero && spread <= 1, "A jitter's spread lies from 0 to 1")
            self.key = key
            self.spread = spread
            self.stream = stream
        }
    }
}

extension Timeline.Jitter {
    /// The weight at an index.
    public func weight(at index: UInt64) -> Rational {
        let steps = Int(Threefry.block(key: key, counter: Threefry.Block(index, stream)).first >> 54)
        do throws(Rational.Error) {
            return 1 + spread * (try Rational(numerator: 2 * steps - 1024, denominator: 1024))
        } catch {
            preconditionFailure("1024 is not zero")
        }
    }
}

extension Timeline.Jitter: Swift.Sequence {
    public func makeIterator() -> LazyMapSequence<PartialRangeFrom<UInt64>, Rational>.Iterator {
        (UInt64(1)...).lazy.map(weight(at:)).makeIterator()
    }
}
