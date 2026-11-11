extension Timeline.Stack {
    public struct Moment {
        public var content: Content
        public var age: Rational
        public var lifetime: Range<Rational>

        public init(content: Content, age: Rational, lifetime: Range<Rational>) {
            self.content = content
            self.age = age
            self.lifetime = lifetime
        }
    }
}

extension Timeline.Stack.Moment: Equatable where Content: Equatable {}
extension Timeline.Stack.Moment: Hashable where Content: Hashable {}
extension Timeline.Stack.Moment: Sendable where Content: Sendable {}

extension Timeline.Stack.Moment {
    public var remaining: Rational { lifetime.upperBound - lifetime.lowerBound - age }
}
