extension Timeline.Stack {
    public enum Error: Swift::Error, Equatable, Sendable {
        case overlap
        case duration
        /// Cuts that do not bound the parts: not one more than the parts, or a cut before the one ahead of it.
        case cuts
    }
}
