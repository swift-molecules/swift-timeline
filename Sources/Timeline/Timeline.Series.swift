extension Timeline {
    /// The instants of events in order, such as the strokes of a hand typing, and how many have happened by an
    /// instant.
    public struct Series: Hashable, Sendable {
        /// The instant of each event, never going back.
        public let instants: [Rational]

        /// The events at instants written in order in source: instants that go back trap, and equal instants are
        /// events that coincide.
        public init(ordered instants: [Rational]) {
            precondition(zip(instants, instants.dropFirst()).allSatisfy { $0 <= $1 }, "A series' instants never go back")
            self.instants = instants
        }

        /// `count` events from `start` to `end`, the gaps in proportion to weights drawn from a sequence, as
        /// ``Timeline/instants(_:from:to:weights:)``; an end before the start traps.
        public init(_ count: Cardinal, from start: Rational, to end: Rational, weights: some Swift.Sequence<Rational>) {
            self.init(ordered: Timeline.instants(count, from: start, to: end, weights: weights))
        }
    }
}

extension Timeline.Series {
    /// How many events have happened at an instant: those at or before it, found by bisection.
    public func count(at time: Rational) -> Cardinal {
        var low = instants.startIndex
        var high = instants.endIndex
        while low < high {
            let middle = low + (high - low) / 2
            if instants[middle] <= time { low = middle + 1 } else { high = middle }
        }
        return Cardinal(UInt(low))
    }
}
