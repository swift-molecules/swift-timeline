extension Timeline.Stack {
    /// Parts laid end to end between cuts: part `i` lives from `cuts[i]` up to `cuts[i + 1]`. A part between two
    /// equal cuts lives over no time and is never alive. Fails with `.cuts` unless there is one more cut than
    /// parts and no cut comes before the one ahead of it.
    public static func sequence(_ contents: [Content], cuts: [Rational]) throws(Error) -> Self {
        guard cuts.count == contents.count + 1, zip(cuts, cuts.dropFirst()).allSatisfy({ $0 <= $1 }) else {
            throw .cuts
        }
        return Self(contents.indices.map { index in Timeline.Layer(contents[index], over: cuts[index]..<cuts[index + 1]) })
    }
}
