public enum Timeline {}

extension Timeline {
    /// The instants of `count` events from `start` to `end`, the gaps between neighbours in proportion to
    /// weights drawn in order from a sequence: the first event at `start`, the last at `end`, exactly.
    ///
    /// The first `count − 1` weights are drawn and the rest of the sequence is left alone, so it may be
    /// endless, such as a random source. Only the weights' proportions matter. Equal weights give equal gaps.
    /// One event is at `start`, and no events is no instants. A sequence that runs short, a negative weight,
    /// or weights that are all zero trap.
    public static func instants(
        _ count: Cardinal,
        from start: Rational,
        to end: Rational,
        weights: some Sequence<Rational>
    ) -> [Rational] {
        let count = Int(bitPattern: count)
        guard count > 1 else { return count == 1 ? [start] : [] }
        let gaps = Array(weights.prefix(count - 1))
        precondition(gaps.count == count - 1, "A stagger draws one weight for each gap")
        precondition(gaps.allSatisfy { $0 >= .zero }, "A gap's weight is not negative")
        let total = gaps.reduce(Rational.zero, +)
        precondition(total > .zero, "A stagger's weights are not all zero")
        let unit: Rational
        do throws(Rational.Error) {
            unit = try (end - start).divided(by: total)
        } catch {
            preconditionFailure("The weights' total is positive")
        }
        var result = [start]
        result.reserveCapacity(count)
        var reached = Rational.zero
        gaps.forEach { gap in
            reached += gap
            result.append(start + reached * unit)
        }
        return result
    }
}
