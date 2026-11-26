public import Rate

extension Timeline.Layer {
    /// The layer with each end moved to the start of the tick of `rate` nearest it, the later of two as near. Two
    /// layers that meet still meet, and a layer shorter than half a tick may come to live over no time.
    public func snapped(to rate: Rate) -> Self {
        Self(content, over: rate.start(of: rate.nearest(to: lifetime.lowerBound))..<rate.start(of: rate.nearest(to: lifetime.upperBound)))
    }
}

extension Timeline.Stack {
    /// The stack with every layer's ends moved to the nearest tick of `rate`: scenes laid on beats, cut on frames.
    public func snapped(to rate: Rate) -> Self { Self(layers.map { $0.snapped(to: rate) }) }
}
