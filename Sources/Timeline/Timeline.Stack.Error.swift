extension Timeline.Stack {
    public enum Error: Swift::Error, Equatable, Sendable {
        case overlap
        case duration
    }
}
