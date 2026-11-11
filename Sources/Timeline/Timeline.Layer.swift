extension Timeline {
    public struct Layer<Content> {
        public var lifetime: Range<Rational>
        public var content: Content

        public init(_ content: Content, over lifetime: Range<Rational>) {
            self.lifetime = lifetime
            self.content = content
        }
    }
}

extension Timeline.Layer: Equatable where Content: Equatable {}
extension Timeline.Layer: Hashable where Content: Hashable {}
extension Timeline.Layer: Sendable where Content: Sendable {}

extension Timeline.Layer {
    public var duration: Rational { lifetime.upperBound - lifetime.lowerBound }

    public func alive(at time: Rational) -> Bool { lifetime.contains(time) }

    public func age(at time: Rational) -> Rational { time - lifetime.lowerBound }

    public func shifted(by offset: Rational) -> Self {
        Self(content, over: (lifetime.lowerBound + offset)..<(lifetime.upperBound + offset))
    }

    public func map<Result, Failure: Swift::Error>(
        _ transform: (Content) throws(Failure) -> Result
    ) throws(Failure) -> Timeline.Layer<Result> {
        Timeline.Layer<Result>(try transform(content), over: lifetime)
    }
}
