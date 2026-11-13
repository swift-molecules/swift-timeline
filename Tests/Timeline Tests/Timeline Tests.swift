import Foundation
import Testing
public import Timeline

extension Double: @retroactive Exponential.`Protocol` {
    public static func exp(_ x: Double) -> Double { Foundation.exp(x) }
    public static func expm1(_ x: Double) -> Double { Foundation.expm1(x) }
    public static func exp2(_ x: Double) -> Double { Foundation.exp2(x) }
    public static func log(_ x: Double) -> Double { Foundation.log(x) }
    public static func log1p(_ x: Double) -> Double { Foundation.log1p(x) }
    public static func log2(_ x: Double) -> Double { Foundation.log2(x) }
    public static func log10(_ x: Double) -> Double { Foundation.log10(x) }
}

extension Double: @retroactive Trigonometry.Circular {
    public static func sin(_ x: Double) -> Double { Foundation.sin(x) }
    public static func cos(_ x: Double) -> Double { Foundation.cos(x) }
    public static func tan(_ x: Double) -> Double { Foundation.tan(x) }
    public static func asin(_ x: Double) -> Double { Foundation.asin(x) }
    public static func acos(_ x: Double) -> Double { Foundation.acos(x) }
    public static func atan(_ x: Double) -> Double { Foundation.atan(x) }
    public static func atan2(_ y: Double, _ x: Double) -> Double { Foundation.atan2(y, x) }
}

enum `Timeline Tests` {}

extension `Timeline Tests` {
    fileprivate typealias Values = Timeline.Track<Double, Double>
    fileprivate typealias Keyframe = Timeline.Track<Double, Double>.Keyframe

    fileprivate struct Failure: Swift::Error, Equatable {}

    fileprivate static func mix(_ from: Double, _ to: Double, _ progress: Double) -> Double {
        from + (to - from) * progress
    }

    fileprivate static func ratio(_ numerator: Int, _ denominator: Int) -> Rational {
        do throws(Rational.Error) {
            return try Rational(numerator: numerator, denominator: denominator)
        } catch {
            preconditionFailure("The tests divide by no zero")
        }
    }

    fileprivate static func timing(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Bezier<Point<2, Double>> {
        Bezier(start: Point(x: 0, y: 0), control1: Point(x: x1, y: y1), control2: Point(x: x2, y: y2), end: Point(x: 1, y: 1))
    }

    /// 0 at 1 s, 10 at 2 s, 40 at 4 s, all linear.
    fileprivate static func ramp() throws(Values.Error) -> Values {
        try Values([Keyframe(at: 1, 0), Keyframe(at: 2, 10), Keyframe(at: 4, 40)])
    }
}

extension `Timeline Tests` {
    @Suite
    struct Easing {
        @Test
        func `An easing turns elapsed time and segment duration into progress`() {
            let late = Timeline.Easing<Double> { elapsed, duration in elapsed - duration }
            #expect(late.progress(3, 5) == -2)
            #expect(Timeline.Easing<Double>.linear.progress(1, 4) == 0.25)
            #expect(Timeline.Easing<Double>.hold.progress(3.9, 4) == 0)
            let square = Timeline.Easing<Double>(fraction: { $0 * $0 })
            #expect(square.progress(1, 4) == 0.0625)
            #expect(square.progress(2, 8) == 0.0625)
        }

        @Test
        func `A Bezier easing maps the curve's x to its y`() throws {
            let curves = [(0.25, 0.1, 0.25, 1.0), (0.42, 0.0, 0.58, 1.0), (0.0, 0.0, 1.0, 1.0), (0.9, -0.4, 0.1, 1.6), (1.0, 0.2, 0.3, 1.0)]
            for (x1, y1, x2, y2) in curves {
                let curve = `Timeline Tests`.timing(x1, y1, x2, y2)
                let easing = try Timeline.Easing<Double>.bezier(curve)
                let points = (1..<64).map { step in
                    curve.value(at: Double(step) / 64) { from, to, parameter in
                        Point(x: `Timeline Tests`.mix(from.x, to.x, parameter), y: `Timeline Tests`.mix(from.y, to.y, parameter))
                    }
                }
                #expect(points.allSatisfy { abs(easing.progress($0.x, 1) - $0.y) < 1e-9 })
            }
        }

        @Test
        func `A Bezier easing starts at zero, ends at one and holds both beyond its ends`() throws {
            let ease = try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(0.25, 0.1, 0.25, 1))
            #expect(ease.progress(0, 2) == 0)
            #expect(ease.progress(2, 2) == 1)
            #expect(ease.progress(-1, 2) == 0)
            #expect(ease.progress(3, 2) == 1)
            #expect(abs(ease.progress(1, 2) - 0.8024033877) < 1e-9)
            let diagonal = try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(1.0 / 3, 1.0 / 3, 2.0 / 3, 2.0 / 3))
            #expect((1..<32).allSatisfy { abs(diagonal.progress(Double($0), 32) - Double($0) / 32) < 1e-15 })
            let symmetric = try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(0.42, 0, 0.58, 1))
            #expect((1..<32).allSatisfy { abs(symmetric.progress(Double($0), 32) + symmetric.progress(Double(32 - $0), 32) - 1) < 1e-12 })
            #expect(abs(symmetric.progress(1, 2) - 0.5) < 1e-15)
        }

        @Test
        func `A Bezier easing is a cubic from the origin to one, one whose x never turns back`() {
            let point = Point<2, Double>(x: 0.5, y: 0.5)
            #expect(throws: Timeline.Easing<Double>.Error.degree) {
                try Timeline.Easing<Double>.bezier(Bezier(start: Point(x: 0, y: 0), control: point, end: Point(x: 1, y: 1)))
            }
            #expect(throws: Timeline.Easing<Double>.Error.endpoints) {
                try Timeline.Easing<Double>.bezier(Bezier(start: Point(x: 0, y: 0.1), control1: point, control2: point, end: Point(x: 1, y: 1)))
            }
            #expect(throws: Timeline.Easing<Double>.Error.endpoints) {
                try Timeline.Easing<Double>.bezier(Bezier(start: Point(x: 0, y: 0), control1: point, control2: point, end: Point(x: 2, y: 1)))
            }
            #expect(throws: Timeline.Easing<Double>.Error.endpoints) {
                try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(0.5, .infinity, 0.5, 1))
            }
            #expect(throws: Timeline.Easing<Double>.Error.monotone) {
                try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(1.2, 0, 0.5, 1))
            }
            #expect(throws: Timeline.Easing<Double>.Error.monotone) {
                try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(0.5, 0, -0.1, 1))
            }
            #expect(throws: Timeline.Easing<Double>.Error.monotone) {
                try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(.nan, 0, 0.5, 1))
            }
        }

        @Test
        func `A spring easing follows elapsed time alone, from zero toward one`() throws {
            let spring = try Spring(frequency: 12.0, ratio: 0.4)
            let easing = Timeline.Easing<Double>.spring(spring)
            #expect(easing.progress(0, 1) == 0)
            #expect(easing.progress(0.3, 1) == easing.progress(0.3, 100))
            #expect(easing.progress(0.3, 1) == 1 - spring.displacement(at: 0.3))
            #expect((1...60).contains { easing.progress(Double($0) / 60, 1) > 1 })
            #expect(abs(easing.progress(5, 1) - 1) < 1e-9)
            let thrown = Timeline.Easing<Double>.spring(spring, velocity: 6)
            let step = 1e-6
            #expect(abs(thrown.progress(step, 1) / step - 6) < 1e-3)
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Track {
        @Test
        func `A track has at least one keyframe, at strictly increasing instants`() throws {
            #expect(throws: `Timeline Tests`.Values.Error.empty) { try `Timeline Tests`.Values([]) }
            #expect(throws: `Timeline Tests`.Values.Error.order) { try `Timeline Tests`.Values([Keyframe(at: 2, 0), Keyframe(at: 1, 1)]) }
            #expect(throws: `Timeline Tests`.Values.Error.order) { try `Timeline Tests`.Values([Keyframe(at: 1, 0), Keyframe(at: 1, 1)]) }
            let track = try `Timeline Tests`.ramp()
            #expect(track.start == 1 && track.end == 4 && track.duration == 3)
            let constant = `Timeline Tests`.Values(constant: 7)
            #expect(constant.start == 0 && constant.duration == 0)
            #expect(constant.value(at: -5, interpolating: `Timeline Tests`.mix) == 7)
            #expect(constant.value(at: 5, interpolating: `Timeline Tests`.mix) == 7)
        }

        @Test
        func `At a keyframe's instant the value is the keyframe's, without easing or interpolation`() throws {
            let calls = Counter()
            let counting = Timeline.Easing<Double> { _, _ in
                calls.increment()
                return .nan
            }
            let track = try `Timeline Tests`.Values([
                Keyframe(at: 1, 0.1, easing: counting), Keyframe(at: 2, 0.2, easing: counting), Keyframe(at: 4, 0.3, easing: counting),
            ])
            var mixes = 0
            func counted(_ from: Double, _ to: Double, _ progress: Double) -> Double {
                mixes += 1
                return .nan
            }
            #expect(track.value(at: 1, interpolating: counted) == 0.1)
            #expect(track.value(at: 2, interpolating: counted) == 0.2)
            #expect(track.value(at: 4, interpolating: counted) == 0.3)
            #expect(track.value(at: 0, interpolating: counted) == 0.1)
            #expect(track.value(at: 9, interpolating: counted) == 0.3)
            #expect(calls.value == 0 && mixes == 0)
            #expect(track.value(at: 3, interpolating: counted).isNaN)
            #expect(calls.value == 1 && mixes == 1)
        }

        @Test
        func `Between keyframes a linear track interpolates at the exact fraction of the segment`() throws {
            let track = try `Timeline Tests`.ramp()
            #expect(track.value(at: `Timeline Tests`.ratio(3, 2), interpolating: `Timeline Tests`.mix) == 5)
            #expect(track.value(at: 3, interpolating: `Timeline Tests`.mix) == 25)
            #expect(track.value(at: `Timeline Tests`.ratio(7, 2), interpolating: `Timeline Tests`.mix) == 32.5)
            let thirds = try `Timeline Tests`.Values([
                Keyframe(at: `Timeline Tests`.ratio(1, 3), 0), Keyframe(at: `Timeline Tests`.ratio(2, 3), 30),
            ])
            #expect(thirds.value(at: `Timeline Tests`.ratio(1, 2), interpolating: `Timeline Tests`.mix) == 15)
            var seen: [Double] = []
            _ = thirds.value(
                at: `Timeline Tests`.ratio(5, 12),
                interpolating: { from, to, progress in
                    seen.append(progress)
                    return from
                }
            )
            #expect(seen == [0.25])
        }

        @Test
        func `A keyframe's easing shapes the segment that leaves it, and progress may leave zero to one`() throws {
            let overshoot = Timeline.Easing<Double>(fraction: { 2 * $0 })
            let track = try `Timeline Tests`.Values([
                Keyframe(at: 0, 0, easing: .hold), Keyframe(at: 1, 10, easing: overshoot), Keyframe(at: 2, 20),
            ])
            #expect(track.value(at: `Timeline Tests`.ratio(999, 1000), interpolating: `Timeline Tests`.mix) == 0)
            #expect(track.value(at: 1, interpolating: `Timeline Tests`.mix) == 10)
            #expect(track.value(at: `Timeline Tests`.ratio(7, 4), interpolating: `Timeline Tests`.mix) == 25)
            #expect(track.value(at: 2, interpolating: `Timeline Tests`.mix) == 20)
        }

        @Test
        func `A value depends on its instant alone: frames evaluate alike in any order`() throws {
            let spring = try Spring(frequency: 9.0, ratio: 0.3)
            let track = try `Timeline Tests`.Values([
                Keyframe(at: 0, 0, easing: .spring(spring)),
                Keyframe(at: 2, 100, easing: .bezier(`Timeline Tests`.timing(0.25, 0.1, 0.25, 1))),
                Keyframe(at: 3, -50),
            ])
            let frames = (0..<120).map { `Timeline Tests`.ratio(1001 * (2 * $0 + 1), 60000) }
            let forward = frames.map { track.value(at: $0, interpolating: `Timeline Tests`.mix) }
            let backward = frames.reversed().map { track.value(at: $0, interpolating: `Timeline Tests`.mix) }
            #expect(forward == backward.reversed())
            let strided = stride(from: 0, to: 120, by: 7).map { track.value(at: frames[$0], interpolating: `Timeline Tests`.mix) }
            #expect(strided == stride(from: 0, to: 120, by: 7).map { forward[$0] })
            #expect(forward[30] == `Timeline Tests`.mix(0, 100, 1 - spring.displacement(at: 1001.0 * 61 / 60000)))
        }

        @Test
        func `The interpolation's typed failure is the evaluation's, and mapping keeps instants and easing`() throws {
            let track = try `Timeline Tests`.ramp()
            func refuse(_ from: Double, _ to: Double, _ progress: Double) throws(Failure) -> Double { throw Failure() }
            #expect(throws: Failure()) { try track.value(at: 3, interpolating: refuse) }
            #expect(try track.value(at: 2, interpolating: refuse) == 10)
            let labels = track.map { "v\(Int($0))" }
            #expect(labels.keyframes.map(\.value) == ["v0", "v10", "v40"])
            #expect(labels.keyframes.map(\.time) == [1, 2, 4])
            #expect(labels.value(at: 3) { from, to, progress in progress < 0.5 ? from : to } == "v40")
        }
    }
}

extension `Timeline Tests` {
    /// A count a `@Sendable` easing can add to.
    fileprivate final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int { lock.withLock { count } }

        func increment() { lock.withLock { count += 1 } }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Arrangement {
        @Test
        func `Shifting moves every instant and stretching scales them about the start`() throws {
            let track = try `Timeline Tests`.ramp()
            let later = track.shifted(by: `Timeline Tests`.ratio(1, 2))
            #expect(later.keyframes.map(\.time) == [`Timeline Tests`.ratio(3, 2), `Timeline Tests`.ratio(5, 2), `Timeline Tests`.ratio(9, 2)])
            #expect(later.value(at: `Timeline Tests`.ratio(7, 2), interpolating: `Timeline Tests`.mix) == 25)
            #expect(track.shifted(by: -1).start == 0)
            let slow = try track.stretched(by: 2)
            #expect(slow.keyframes.map(\.time) == [1, 3, 7])
            #expect(slow.value(at: 5, interpolating: `Timeline Tests`.mix) == 25)
            #expect(try track.stretched(by: `Timeline Tests`.ratio(1, 3)).end == 2)
            #expect(throws: `Timeline Tests`.Values.Error.factor) { try track.stretched(by: 0) }
            #expect(throws: `Timeline Tests`.Values.Error.factor) { try track.stretched(by: -1) }
        }

        @Test
        func `A reversed track plays the same values backwards over the same span`() throws {
            let ease = try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(0.42, 0, 1, 1))
            let track = try `Timeline Tests`.Values([Keyframe(at: 1, 0, easing: ease), Keyframe(at: 2, 10), Keyframe(at: 4, 40, easing: .hold)])
            let reversed = track.reversed
            #expect(reversed.start == 1 && reversed.end == 4)
            #expect(reversed.keyframes.map(\.value) == [40, 10, 0])
            #expect(reversed.keyframes.map(\.time) == [1, 3, 4])
            for time in (0...60).map({ 1 + `Timeline Tests`.ratio($0, 20) }) {
                let mirrored = track.value(at: 5 - time, interpolating: `Timeline Tests`.mix)
                #expect(abs(reversed.value(at: time, interpolating: `Timeline Tests`.mix) - mirrored) < 1e-12)
                let twice = reversed.reversed.value(at: time, interpolating: `Timeline Tests`.mix)
                #expect(abs(twice - track.value(at: time, interpolating: `Timeline Tests`.mix)) < 1e-12)
            }
        }

        @Test
        func `Appending plays another track after a gap, which the last keyframe's easing bridges`() throws {
            let first = try `Timeline Tests`.Values([Keyframe(at: 0, 0), Keyframe(at: 1, 10, easing: .hold)])
            let second = try `Timeline Tests`.Values([Keyframe(at: 100, 50), Keyframe(at: 102, 70)])
            let joined = try first.appending(second, after: `Timeline Tests`.ratio(1, 2))
            #expect(joined.keyframes.map(\.time) == [0, 1, `Timeline Tests`.ratio(3, 2), `Timeline Tests`.ratio(7, 2)])
            #expect(joined.value(at: `Timeline Tests`.ratio(5, 4), interpolating: `Timeline Tests`.mix) == 10)
            #expect(joined.value(at: `Timeline Tests`.ratio(3, 2), interpolating: `Timeline Tests`.mix) == 50)
            #expect(joined.value(at: `Timeline Tests`.ratio(5, 2), interpolating: `Timeline Tests`.mix) == 60)
            let glide = try `Timeline Tests`.ramp().appending(second, after: 1)
            #expect(glide.value(at: `Timeline Tests`.ratio(9, 2), interpolating: `Timeline Tests`.mix) == 45)
            #expect(throws: `Timeline Tests`.Values.Error.order) { try first.appending(second, after: 0) }
            #expect(throws: `Timeline Tests`.Values.Error.order) { try first.appending(second, after: -1) }
        }

        @Test
        func `Staggering gives copies of a track, each one interval after the one before`() throws {
            let track = try `Timeline Tests`.ramp()
            let copies = track.staggered(count: 4, every: `Timeline Tests`.ratio(1, 10))
            #expect(copies.map(\.start) == [1, `Timeline Tests`.ratio(11, 10), `Timeline Tests`.ratio(12, 10), `Timeline Tests`.ratio(13, 10)])
            let time = `Timeline Tests`.ratio(3, 2)
            let values = copies.map { $0.value(at: time, interpolating: `Timeline Tests`.mix) }
            #expect(zip(values, [5.0, 4, 3, 2]).allSatisfy { abs($0 - $1) < 1e-12 })
            #expect(track.staggered(count: 0, every: 1).isEmpty)
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Loop {
        @Test
        func `A loop maps an instant into its first cycle, exactly`() throws {
            let loop = try Timeline.Loop(period: `Timeline Tests`.ratio(1, 3))
            #expect(loop.time(at: 0) == 0)
            #expect(loop.time(at: `Timeline Tests`.ratio(1, 4)) == `Timeline Tests`.ratio(1, 4))
            #expect(loop.time(at: `Timeline Tests`.ratio(1, 3)) == 0)
            #expect(loop.time(at: `Timeline Tests`.ratio(5, 12)) == `Timeline Tests`.ratio(1, 12))
            #expect(loop.time(at: 1000 + `Timeline Tests`.ratio(1, 7)) == `Timeline Tests`.ratio(1, 7))
            #expect(loop.time(at: -2) == -2)
            #expect(throws: Timeline.Loop.Error.period) { try Timeline.Loop(period: 0) }
            #expect(throws: Timeline.Loop.Error.period) { try Timeline.Loop(period: -1) }
        }

        @Test
        func `An alternating loop runs back on every second cycle`() throws {
            let loop = try Timeline.Loop(period: 2, alternates: true)
            #expect(loop.time(at: `Timeline Tests`.ratio(3, 2)) == `Timeline Tests`.ratio(3, 2))
            #expect(loop.time(at: 2) == 2)
            #expect(loop.time(at: `Timeline Tests`.ratio(5, 2)) == `Timeline Tests`.ratio(3, 2))
            #expect(loop.time(at: 4) == 0)
            #expect(loop.time(at: `Timeline Tests`.ratio(9, 2)) == `Timeline Tests`.ratio(1, 2))
            #expect(loop.time(at: `Timeline Tests`.ratio(15, 2)) == `Timeline Tests`.ratio(1, 2))
        }

        @Test
        func `A counted loop stays where its last cycle ended`() throws {
            let thrice = try Timeline.Loop(period: 2, count: 3)
            #expect(thrice.time(at: `Timeline Tests`.ratio(11, 2)) == `Timeline Tests`.ratio(3, 2))
            #expect(thrice.time(at: 6) == 2)
            #expect(thrice.time(at: 600) == 2)
            let there = try Timeline.Loop(period: 2, count: 3, alternates: true)
            #expect(there.time(at: `Timeline Tests`.ratio(11, 2)) == `Timeline Tests`.ratio(3, 2))
            #expect(there.time(at: 7) == 2)
            let back = try Timeline.Loop(period: 2, count: 2, alternates: true)
            #expect(back.time(at: `Timeline Tests`.ratio(7, 2)) == `Timeline Tests`.ratio(1, 2))
            #expect(back.time(at: 4) == 0 && back.time(at: 9) == 0)
            #expect(try Timeline.Loop(period: 2, count: 0).time(at: 1) == 0)
        }

        @Test
        func `A looped track repeats from its own start`() throws {
            let track = try `Timeline Tests`.Values([Keyframe(at: 10, 0), Keyframe(at: 11, 8)])
            let loop = try Timeline.Loop(period: 1)
            let swing = try Timeline.Loop(period: 1, alternates: true)
            func value(_ numerator: Int, _ loop: Timeline.Loop) -> Double {
                track.value(at: `Timeline Tests`.ratio(numerator, 4), looping: loop, interpolating: `Timeline Tests`.mix)
            }
            #expect([40, 41, 43, 44, 45, 49, 4001].map { value($0, loop) } == [0, 2, 6, 0, 2, 2, 2])
            #expect([40, 41, 43, 44, 45, 47, 48, 49].map { value($0, swing) } == [0, 2, 6, 8, 6, 2, 0, 2])
            #expect(value(36, loop) == 0)
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Layers {
        @Test
        func `A layer is alive from its start up to but not at its end, and its age counts from the start`() {
            let layer = Timeline.Layer("title", over: 2..<5)
            #expect(layer.alive(at: 2) && layer.alive(at: `Timeline Tests`.ratio(499, 100)))
            #expect(!layer.alive(at: 5) && !layer.alive(at: `Timeline Tests`.ratio(199, 100)))
            #expect(layer.duration == 3)
            #expect(layer.age(at: `Timeline Tests`.ratio(7, 2)) == `Timeline Tests`.ratio(3, 2))
            #expect(layer.shifted(by: 10).lifetime == 12..<15)
            #expect(layer.map(\.count) == Timeline.Layer(5, over: 2..<5))
            #expect(!Timeline.Layer("never", over: 3..<3).alive(at: 3))
        }

        @Test
        func `A stack answers the layers alive at an instant, in order, each with its age`() {
            let stack = Timeline.Stack([
                Timeline.Layer("scene one", over: 0..<4),
                Timeline.Layer("scene two", over: 4..<9),
                Timeline.Layer("meter", over: 2..<8),
            ])
            #expect(stack.span == 0..<9)
            #expect(Timeline.Stack<String>().span == nil)
            #expect(stack.alive(at: 1).map(\.content) == ["scene one"])
            #expect(stack.alive(at: 3).map(\.content) == ["scene one", "meter"])
            #expect(stack.alive(at: 4).map(\.content) == ["scene two", "meter"])
            #expect(stack.alive(at: 4).map(\.age) == [0, 2])
            #expect(stack.alive(at: 4).map(\.remaining) == [5, 4])
            #expect(stack.alive(at: 8).map(\.content) == ["scene two"])
            #expect(stack.alive(at: 9).isEmpty && stack.alive(at: -1).isEmpty)
            #expect(stack.shifted(by: 1).span == 1..<10)
            #expect(stack.appending(Timeline.Stack([Timeline.Layer("end", over: 9..<10)])).layers.count == 4)
        }

        @Test
        func `A layer that spans a cut keeps one continuous age across it`() throws {
            let scenes = try Timeline.Stack.sequence([("terminal", 5), ("checklist", 12), ("torus", 5)])
            let stack = scenes.appending(Timeline.Stack([Timeline.Layer("meter", over: 3..<20)]))
            let before = stack.alive(at: `Timeline Tests`.ratio(4999, 1000))
            let after = stack.alive(at: 5)
            #expect(before.map(\.content) == ["terminal", "meter"])
            #expect(after.map(\.content) == ["checklist", "meter"])
            #expect(after[0].age == 0)
            #expect(after[1].age - before[1].age == `Timeline Tests`.ratio(1, 1000))
        }

        @Test
        func `A sequence without overlap has exactly one layer alive at every instant of its span`() throws {
            let stack = try Timeline.Stack.sequence([("a", 2), ("b", `Timeline Tests`.ratio(1, 3)), ("c", 4)], from: 10)
            #expect(stack.layers.map(\.lifetime) == [10..<12, 12..<(12 + `Timeline Tests`.ratio(1, 3)), (12 + `Timeline Tests`.ratio(1, 3))..<(16 + `Timeline Tests`.ratio(1, 3))])
            let instants = (0..<190).map { 10 + `Timeline Tests`.ratio($0, 30) }
            #expect(instants.allSatisfy { stack.alive(at: $0).count == 1 })
            #expect(stack.alive(at: 12).map(\.content) == ["b"])
            #expect(stack.alive(at: 16 + `Timeline Tests`.ratio(1, 3)).isEmpty)
        }

        @Test
        func `With an overlap two layers are alive for exactly that long around each cut`() throws {
            let overlap = `Timeline Tests`.ratio(1, 2)
            let stack = try Timeline.Stack.sequence([("a", 3), ("b", 3), ("c", 3)], overlap: overlap)
            #expect(stack.layers.map(\.lifetime.lowerBound) == [0, `Timeline Tests`.ratio(5, 2), 5])
            #expect(stack.span == 0..<8)
            #expect(stack.alive(at: `Timeline Tests`.ratio(249, 100)).map(\.content) == ["a"])
            #expect(stack.alive(at: `Timeline Tests`.ratio(5, 2)).map(\.content) == ["a", "b"])
            #expect(stack.alive(at: `Timeline Tests`.ratio(299, 100)).map(\.content) == ["a", "b"])
            #expect(stack.alive(at: 3).map(\.content) == ["b"])
            let fade = stack.alive(at: `Timeline Tests`.ratio(11, 4))
            #expect(fade.map(\.age) == [`Timeline Tests`.ratio(11, 4), `Timeline Tests`.ratio(1, 4)])
            #expect(fade.map(\.remaining) == [`Timeline Tests`.ratio(1, 4), `Timeline Tests`.ratio(11, 4)])
            #expect(throws: Timeline.Stack<String>.Error.overlap) { try Timeline.Stack.sequence([("a", 3)], overlap: -1) }
            #expect(throws: Timeline.Stack<String>.Error.duration) { try Timeline.Stack.sequence([("a", 3), ("b", 1)], overlap: 1) }
            #expect(throws: Timeline.Stack<String>.Error.duration) { try Timeline.Stack.sequence([("a", 0)]) }
        }

        @Test
        func `Staggered layers share a duration and start one interval apart`() throws {
            let stack = try Timeline.Stack.stagger(["c", "l", "i"], duration: 1, from: 2, every: `Timeline Tests`.ratio(1, 10))
            #expect(stack.layers.map(\.lifetime.lowerBound) == [2, `Timeline Tests`.ratio(21, 10), `Timeline Tests`.ratio(22, 10)])
            #expect(stack.layers.allSatisfy { $0.duration == 1 })
            #expect(stack.alive(at: `Timeline Tests`.ratio(215, 100)).map(\.content) == ["c", "l"])
            #expect(stack.alive(at: `Timeline Tests`.ratio(305, 100)).map(\.content) == ["l", "i"])
            #expect(throws: Timeline.Stack<String>.Error.duration) { try Timeline.Stack.stagger(["x"], duration: -1, every: 1) }
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Shorthand {
        @Test
        func `Four numbers make the Bezier easing the curve through them would`() throws {
            let numbers = Timeline.Easing<Double>.bezier(0.16, 1, 0.3, 1)
            let curve = try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(0.16, 1, 0.3, 1))
            #expect((0...40).allSatisfy { numbers.progress(Double($0), 40) == curve.progress(Double($0), 40) })
        }

        @Test
        func `Named easings run from zero to one, hold beyond their ends, and have their shapes`() {
            let easings: [Timeline.Easing<Double>] = [.smooth, .easeIn(), .easeOut(), .easeInOut(), .easeIn(power: 3), .easeOut(power: 4), .easeInOut(power: 3)]
            for easing in easings {
                #expect(easing.progress(0, 1) == 0 && easing.progress(1, 1) == 1)
                #expect(easing.progress(-1, 1) == 0 && easing.progress(2, 1) == 1)
                #expect((0..<32).allSatisfy { easing.progress(Double($0), 32) <= easing.progress(Double($0 + 1), 32) })
            }
            #expect(Timeline.Easing<Double>.smooth.progress(1, 4) == 0.15625)
            #expect(Timeline.Easing<Double>.smooth.progress(1, 2) == 0.5)
            #expect(Timeline.Easing<Double>.easeIn(power: 3).progress(1, 2) == 0.125)
            #expect(Timeline.Easing<Double>.easeOut(power: 4).progress(1, 2) == 0.9375)
            #expect(Timeline.Easing<Double>.easeInOut().progress(1, 4) == 0.125)
            #expect(Timeline.Easing<Double>.easeInOut().progress(3, 4) == 0.875)
            #expect(Timeline.Easing<Double>.easeInOut(power: 3).progress(1, 2) == 0.5)
        }

        @Test
        func `Keys in order make a track without a throw, and steps hold each value until the next`() {
            let track = `Timeline Tests`.Values(ordered: [(1, 0), (2, 10), (4, 40)])
            #expect(track.keyframes.map(\.time) == [1, 2, 4])
            #expect(track.value(at: 3) == 25 && track.value(at: 0) == 0 && track.value(at: 9) == 40)
            let eased = `Timeline Tests`.Values(ordered: [(0, 0), (2, 1)], easing: .smooth)
            #expect(eased.value(at: `Timeline Tests`.ratio(1, 2)) == 0.15625)
            let steps = `Timeline Tests`.Values.steps([(0, 0), (2, 1), (3, 0)])
            #expect(steps.value(at: `Timeline Tests`.ratio(199, 100)) == 0)
            #expect(steps.value(at: 2) == 1 && steps.value(at: `Timeline Tests`.ratio(299, 100)) == 1)
            #expect(steps.value(at: 3) == 0 && steps.value(at: 10) == 0)
            let keyframes = `Timeline Tests`.Values(ordered: [Keyframe(at: 0, 0, easing: .hold), Keyframe(at: 1, 1)])
            #expect(keyframes.value(at: `Timeline Tests`.ratio(1, 2)) == 0)
        }

        @Test
        func `A Scalar track is mixed straight, also when looped`() throws {
            let track = try `Timeline Tests`.ramp()
            let times = (0...50).map { `Timeline Tests`.ratio($0, 10) }
            #expect(times.allSatisfy { track.value(at: $0) == track.value(at: $0, interpolating: `Timeline Tests`.mix) })
            let loop = try Timeline.Loop(period: 1)
            #expect(track.value(at: `Timeline Tests`.ratio(5, 2), looping: loop) == 5)
        }

        @Test
        func `A ramp rises from zero to one over its duration on its easing`() {
            let ramp = `Timeline Tests`.Values.ramp(at: 2, lasting: 4)
            #expect(ramp.value(at: 1) == 0 && ramp.value(at: 2) == 0)
            #expect(ramp.value(at: 3) == 0.25 && ramp.value(at: 6) == 1 && ramp.value(at: 9) == 1)
            let smooth = `Timeline Tests`.Values.ramp(at: 0, lasting: 2, easing: .smooth)
            #expect(smooth.value(at: `Timeline Tests`.ratio(1, 2)) == 0.15625)
        }

        @Test
        func `Hits jump to their strength and die away to zero`() {
            let hits = `Timeline Tests`.Values.hits([(at: 1, strength: 1, lasting: 2), (at: 4, strength: 0.5, lasting: 1), (at: 10, strength: 0.8, lasting: 4)])
            #expect(hits.value(at: -100) == 0 && hits.value(at: `Timeline Tests`.ratio(99, 100)) == 0)
            #expect(hits.value(at: 1) == 1)
            #expect(abs(hits.value(at: 2) - 0.125) < 1e-15)
            #expect(hits.value(at: 3) == 0 && hits.value(at: `Timeline Tests`.ratio(399, 100)) == 0)
            #expect(hits.value(at: 4) == 0.5)
            #expect(hits.value(at: 5) == 0 && hits.value(at: 7) == 0 && hits.value(at: `Timeline Tests`.ratio(999, 100)) == 0)
            #expect(hits.value(at: 10) == 0.8 && hits.value(at: 14) == 0 && hits.value(at: 100) == 0)
            let even = `Timeline Tests`.Values.hits([(at: 0, strength: 1, lasting: 4)], easing: .linear)
            #expect(even.value(at: 1) == 0.75)
            #expect(`Timeline Tests`.Values.hits([]).value(at: 3) == 0)
        }

        @Test
        func `A smooth curve passes through every key, meets each with its neighbours' slope, and is cubic between`() {
            let keys: [(Rational, Double)] = [(0, 0), (1, 2), (3, 2), (4, 10)]
            let track = `Timeline Tests`.Values(ordered: keys)
            #expect(keys.allSatisfy { track.smooth(at: $0.0) == $0.1 })
            #expect(track.smooth(at: -1) == 0 && track.smooth(at: 5) == 10)
            let step = 1e-6
            func slope(_ time: Double) -> Double {
                let near = { (offset: Double) in
                    track.smooth(at: Rational(Int((time + offset) * 1e7)) * `Timeline Tests`.ratio(1, 10_000_000))
                }
                return (near(step) - near(-step)) / (2 * step)
            }
            #expect(abs(slope(1) - 2.0 / 3) < 1e-4)
            #expect(abs(slope(3) - 8.0 / 3) < 1e-4)
            // On the first segment, slope 2 leaving 0 and 2/3 entering 1: Hermite at one half.
            let half = 0.5 * 0 + 0.125 * 2 + 0.5 * 2 - 0.125 * (2.0 / 3)
            #expect(abs(track.smooth(at: `Timeline Tests`.ratio(1, 2)) - half) < 1e-15)
            let resting = track.smooth(at: `Timeline Tests`.ratio(7, 2), first: 0, last: 0)
            // Slope 8/3 leaving 3 and none entering 4.
            #expect(abs(resting - (0.5 * 2 + 0.125 * 8.0 / 3 + 0.5 * 10)) < 1e-12)
            let line = `Timeline Tests`.Values(ordered: [(0, 0), (1, 1), (2, 2)])
            #expect((0...20).allSatisfy { abs(line.smooth(at: `Timeline Tests`.ratio($0, 10)) - Double($0) / 10) < 1e-15 })
        }
    }
}
