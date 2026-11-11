extension Timeline.Track {
    public enum Error: Swift::Error, Equatable, Sendable {
        case empty
        case order
        case factor
    }
}
