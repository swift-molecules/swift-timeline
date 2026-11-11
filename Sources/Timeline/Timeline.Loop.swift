extension Timeline {
    public struct Loop: Hashable, Sendable {
        public let period: Rational
        public let count: Cardinal?
        public let alternates: Bool

        public init(period: Rational, count: Cardinal? = nil, alternates: Bool = false) throws(Error) {
            guard period > .zero else { throw .period }
            self.period = period
            self.count = count
            self.alternates = alternates
        }
    }
}

extension Timeline.Loop {
    public func time(at time: Rational) -> Rational {
        guard time > .zero else { return time }
        if let count {
            let cycles = Rational(Int(clamping: count))
            if time >= cycles * period {
                guard count > .zero else { return .zero }
                return alternates && Int(clamping: count).isMultiple(of: 2) ? .zero : period
            }
        }
        let span = alternates ? period + period : period
        let phase = time - Self.floor(time, over: span) * span
        return phase <= period ? phase : span - phase
    }

    /// The whole number of `divisor`s in a time that is not negative.
    private static func floor(_ time: Rational, over divisor: Rational) -> Rational {
        let ratio = time.numerator * divisor.denominator
        let whole = divisor.numerator * time.denominator
        do throws(Integer.Error) {
            return Rational(try ratio.quotientAndRemainder(dividingBy: whole).quotient)
        } catch {
            preconditionFailure("A loop's period is not zero")
        }
    }
}
