extension Timeline {
    public struct Stack<Content> {
        public var layers: [Layer<Content>]

        public init(_ layers: [Layer<Content>] = []) {
            self.layers = layers
        }
    }
}

extension Timeline.Stack: Equatable where Content: Equatable {}
extension Timeline.Stack: Hashable where Content: Hashable {}
extension Timeline.Stack: Sendable where Content: Sendable {}

extension Timeline.Stack {
    public var span: Range<Rational>? {
        guard let start = layers.map(\.lifetime.lowerBound).min(), let end = layers.map(\.lifetime.upperBound).max() else {
            return nil
        }
        return start..<end
    }

    public func alive(at time: Rational) -> [Moment] {
        layers.filter { $0.alive(at: time) }.map { Moment(content: $0.content, age: $0.age(at: time), lifetime: $0.lifetime) }
    }

    public func appending(_ other: Self) -> Self { Self(layers + other.layers) }

    public func shifted(by offset: Rational) -> Self { Self(layers.map { $0.shifted(by: offset) }) }

    public static func sequence(
        _ parts: [(content: Content, duration: Rational)],
        from start: Rational = .zero,
        overlap: Rational = .zero
    ) throws(Error) -> Self {
        guard overlap >= .zero else { throw .overlap }
        guard parts.allSatisfy({ $0.duration > overlap }) else { throw .duration }
        var layers: [Timeline.Layer<Content>] = []
        layers.reserveCapacity(parts.count)
        var time = start
        parts.forEach { part in
            layers.append(Timeline.Layer(part.content, over: time..<(time + part.duration)))
            time += part.duration - overlap
        }
        return Self(layers)
    }

    public static func stagger(
        _ contents: [Content],
        duration: Rational,
        from start: Rational = .zero,
        every interval: Rational
    ) throws(Error) -> Self {
        guard duration >= .zero else { throw .duration }
        var layers: [Timeline.Layer<Content>] = []
        layers.reserveCapacity(contents.count)
        var time = start
        contents.forEach { content in
            layers.append(Timeline.Layer(content, over: time..<(time + duration)))
            time += interval
        }
        return Self(layers)
    }
}
