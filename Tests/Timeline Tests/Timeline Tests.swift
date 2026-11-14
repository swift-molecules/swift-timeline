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

        @Test
        func `A spring easing from frequency and ratio is the easing of that spring`() throws {
            let spring = try Spring(frequency: 12.0, ratio: 0.4)
            let short = Timeline.Easing<Double>.spring(frequency: 12, ratio: 0.4, velocity: 3)
            let long = Timeline.Easing<Double>.spring(spring, velocity: 3)
            #expect([0, 0.05, 0.3, 2].allSatisfy { short.progress($0, 1) == long.progress($0, 1) })
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
                interpolating: { from, _, progress in
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

        @Test
        func `An uneven stagger matches the even one for equal weights`() throws {
            let track = try `Timeline Tests`.ramp()
            let even = track.staggered(count: 4, every: `Timeline Tests`.ratio(1, 10))
            let weighted = track.staggered(count: 4, over: `Timeline Tests`.ratio(3, 10), weights: repeatElement(Rational(1), count: 3))
            #expect(weighted.map(\.start) == even.map(\.start))
            let uneven = track.staggered(count: 3, over: 2, weights: [1, 3])
            #expect(uneven.map(\.start) == [1, `Timeline Tests`.ratio(3, 2), 3])
            #expect(track.staggered(count: 0, over: 2, weights: [Rational]()).isEmpty)
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
            let easings: [Timeline.Easing<Double>] = [.smooth, .power(1), .power(2), .power(2).reversed, .power(2).symmetric, .power(3), .power(4).reversed, .power(3).symmetric]
            for easing in easings {
                #expect(easing.progress(0, 1) == 0 && easing.progress(1, 1) == 1)
                #expect(easing.progress(-1, 1) == 0 && easing.progress(2, 1) == 1)
                #expect((0..<32).allSatisfy { easing.progress(Double($0), 32) <= easing.progress(Double($0 + 1), 32) })
            }
            #expect(Timeline.Easing<Double>.smooth.progress(1, 4) == 0.15625)
            #expect(Timeline.Easing<Double>.smooth.progress(1, 2) == 0.5)
            #expect(Timeline.Easing<Double>.power(3).progress(1, 2) == 0.125)
            #expect(Timeline.Easing<Double>.power(4).reversed.progress(1, 2) == 0.9375)
            #expect(Timeline.Easing<Double>.power(2).symmetric.progress(1, 4) == 0.125)
            #expect(Timeline.Easing<Double>.power(2).symmetric.progress(3, 4) == 0.875)
            #expect(Timeline.Easing<Double>.power(3).symmetric.progress(1, 2) == 0.5)
            #expect((0...32).allSatisfy { Timeline.Easing<Double>.power(1).progress(Double($0), 32) == Double($0) / 32 })
        }

        @Test
        func `An easing reversed is one minus its progress at the time left, and reversing twice is the easing up to rounding`() throws {
            let curve = try Timeline.Easing<Double>.bezier(`Timeline Tests`.timing(0.7, 0, 0.84, 0))
            for easing in [curve, .smooth, .power(3)] {
                (0...16).forEach { step in
                    let elapsed = Double(step) / 4
                    #expect(easing.reversed.progress(elapsed, 4) == 1 - easing.progress(4 - elapsed, 4))
                    #expect(abs(easing.reversed.reversed.progress(elapsed, 4) - easing.progress(elapsed, 4)) < 1e-15)
                }
            }
        }

        @Test
        func `A symmetric easing is the easing over the first half and its reverse over the second`() {
            let easing = Timeline.Easing<Double>.power(3)
            let symmetric = easing.symmetric
            #expect(symmetric.progress(2, 4) == 0.5)
            (0...8).forEach { step in
                let elapsed = Double(step) / 4
                #expect(symmetric.progress(elapsed, 4) == easing.progress(2 * elapsed, 4) / 2)
                #expect(abs(symmetric.progress(4 - elapsed, 4) - (1 - symmetric.progress(elapsed, 4))) < 1e-15)
            }
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
        func `Pulses jump to their peak and die away to zero`() {
            let hits = `Timeline Tests`.Values.pulses(
                [(at: 1, peak: 1, lasting: 2), (at: 4, peak: 0.5, lasting: 1), (at: 10, peak: 0.8, lasting: 4)],
                easing: .power(3).reversed
            )
            #expect(hits.value(at: -100) == 0 && hits.value(at: `Timeline Tests`.ratio(99, 100)) == 0)
            #expect(hits.value(at: 1) == 1)
            #expect(abs(hits.value(at: 2) - 0.125) < 1e-15)
            #expect(hits.value(at: 3) == 0 && hits.value(at: `Timeline Tests`.ratio(399, 100)) == 0)
            #expect(hits.value(at: 4) == 0.5)
            #expect(hits.value(at: 5) == 0 && hits.value(at: 7) == 0 && hits.value(at: `Timeline Tests`.ratio(999, 100)) == 0)
            #expect(hits.value(at: 10) == 0.8 && hits.value(at: 14) == 0 && hits.value(at: 100) == 0)
            #expect(hits.start == -1)
            let even = `Timeline Tests`.Values.pulses([(at: 0, peak: 1, lasting: 4)])
            #expect(even.value(at: 1) == 0.75)
            #expect(`Timeline Tests`.Values.pulses([]).value(at: 3) == 0)
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
            // At the last key the slope is that to its one neighbour: 8 from 3 to 4.
            #expect(abs(slope(4 - 2 * step) - 8) < 1e-4)
            let line = `Timeline Tests`.Values(ordered: [(0, 0), (1, 1), (2, 2)])
            #expect((0...20).allSatisfy { abs(line.smooth(at: `Timeline Tests`.ratio($0, 10)) - Double($0) / 10) < 1e-15 })
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Instants {
        /// An endless deterministic source of weights in 0..<1, the way a caller's random source would give them.
        fileprivate static func draws(seed: UInt64) -> some Swift.Sequence<Rational> {
            var state = seed
            return AnyIterator<Rational> {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return `Timeline Tests`.ratio(Int(state >> 54), 1024)
            }
            .lazy
        }

        @Test
        func `The first instant is the start and the last the end, exactly`() {
            let (start, end) = (`Timeline Tests`.ratio(1001, 30000), `Timeline Tests`.ratio(7, 3))
            let instants = Timeline.instants(9, from: start, to: end, weights: Self.draws(seed: 7))
            #expect(instants.count == 9)
            #expect(instants.first == start)
            #expect(instants.last == end)
            let exact = Timeline.instants(3, from: 0, to: 2, weights: [1, 3])
            #expect(exact == [0, `Timeline Tests`.ratio(1, 2), 2])
        }

        @Test
        func `Instants never go back, and a zero weight makes two coincide`() {
            [UInt64(1), 2, 3, 99].forEach { seed in
                let instants = Timeline.instants(40, from: -1, to: 5, weights: Self.draws(seed: seed))
                #expect(zip(instants, instants.dropFirst()).allSatisfy { $0 <= $1 })
            }
            let instants = Timeline.instants(4, from: 0, to: 1, weights: [1, 0, 1])
            #expect(instants == [0, `Timeline Tests`.ratio(1, 2), `Timeline Tests`.ratio(1, 2), 1])
        }

        @Test
        func `Equal weights give the even stagger`() {
            let instants = Timeline.instants(6, from: 2, to: 7, weights: repeatElement(`Timeline Tests`.ratio(1, 3), count: 5))
            #expect(instants == [2, 3, 4, 5, 6, 7])
        }

        @Test
        func `Only the weights' proportions matter`() {
            let weights = Array(Self.draws(seed: 11).prefix(7))
            let factor = `Timeline Tests`.ratio(7, 3)
            let plain = Timeline.instants(8, from: 1, to: 4, weights: weights)
            let scaled = Timeline.instants(8, from: 1, to: 4, weights: weights.map { $0 * factor })
            #expect(plain == scaled)
        }

        @Test
        func `No events, one event and two events`() {
            #expect(Timeline.instants(0, from: 1, to: 4, weights: [Rational]()).isEmpty)
            #expect(Timeline.instants(1, from: 1, to: 4, weights: [Rational]()) == [1])
            #expect(Timeline.instants(2, from: 1, to: 4, weights: [`Timeline Tests`.ratio(1, 1000)]) == [1, 4])
            #expect(Timeline.instants(2, from: 1, to: 4, weights: Self.draws(seed: 5)) == [1, 4])
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Tail {
        @Test
        func `A tail is the last value up to its instant and after it runs on by elapsed time alone`() throws {
            let spring = try Spring(frequency: 8.0, ratio: 0.6)
            let track = `Timeline Tests`.Values(from: 0, at: 2, tail: .spring(toward: 1, spring))
            #expect(track.start == 2 && track.end == 2)
            #expect(track.value(at: 1) == 0 && track.value(at: 2) == 0)
            #expect(track.value(at: `Timeline Tests`.ratio(9, 4)) == 1 - spring.displacement(at: 0.25))
            #expect(track.value(at: 102) != track.value(at: 2))
            #expect(abs(track.value(at: 22) - 1) < 1e-12)
            let easing = Timeline.Easing<Double>.spring(spring, velocity: 3)
            let tail = `Timeline Tests`.Values.Tail.spring(toward: 1, spring, velocity: 3)
            #expect([0, 0.05, 0.3, 2].allSatisfy { tail.progress($0) == easing.progress($0, 1) })
            let short = `Timeline Tests`.Values.Tail.spring(toward: 1, frequency: 8, ratio: 0.6, velocity: 3)
            #expect([0, 0.05, 0.3, 2].allSatisfy { short.progress($0) == tail.progress($0) })
        }

        @Test
        func `A tail leaves the last keyframe toward its value, and its progress is not called at that keyframe`() throws {
            let calls = Counter()
            let tail = `Timeline Tests`.Values.Tail(toward: 20) { elapsed in
                calls.increment()
                return elapsed
            }
            let track = try `Timeline Tests`.Values([Keyframe(at: 0, 0), Keyframe(at: 1, 10)], tail: tail)
            #expect(track.value(at: `Timeline Tests`.ratio(1, 2)) == 5 && track.value(at: 1) == 10)
            #expect(calls.value == 0)
            #expect(track.value(at: `Timeline Tests`.ratio(5, 4)) == 12.5)
            #expect(track.value(at: 3) == 30)
            #expect(calls.value == 2)
            #expect(try `Timeline Tests`.Values([Keyframe(at: 0, 0), Keyframe(at: 1, 10)]).value(at: 3) == 10)
        }

        @Test
        func `A track appended after a tail cuts it, bridging the gap by the last easing, and brings its own tail`() throws {
            let first = `Timeline Tests`.Values(ordered: [(0, 0), (1, 10)], easing: .hold)
            let open = try `Timeline Tests`.Values(first.keyframes, tail: .init(toward: 99) { $0 })
            let second = `Timeline Tests`.Values(from: 50, at: 0, tail: .init(toward: 60) { $0 })
            let joined = try open.appending(second, after: 1)
            #expect(joined.value(at: `Timeline Tests`.ratio(3, 2)) == 10)
            #expect(joined.value(at: 2) == 50)
            #expect(joined.value(at: `Timeline Tests`.ratio(5, 2)) == 55)
            #expect(joined.tail?.value == 60)
        }

        @Test
        func `Shifting, stretching and mapping keep a tail, which counts seconds after the last keyframe; reversing drops it`() throws {
            let track = `Timeline Tests`.Values(ordered: [Keyframe(at: 0, 0), Keyframe(at: 1, 10)], tail: .init(toward: 20) { $0 })
            #expect(track.shifted(by: 5).value(at: `Timeline Tests`.ratio(13, 2)) == 15)
            #expect(try track.stretched(by: 2).value(at: `Timeline Tests`.ratio(5, 2)) == 15)
            let labels = track.map { "v\(Int($0))" }
            #expect(labels.tail?.value == "v20")
            #expect(labels.value(at: 9) { from, to, progress in progress < 0.5 ? from : to } == "v20")
            #expect(track.reversed.tail == nil)
            #expect(track.reversed.value(at: 3) == 0)
            #expect(track.staggered(count: 2, every: 1)[1].value(at: `Timeline Tests`.ratio(5, 2)) == 15)
        }
    }
}

extension `Timeline Tests` {
    /// Two numbers mixed one by one, the least value that is not a scalar.
    fileprivate struct Pair: Equatable {
        var x: Double
        var y: Double

        static func mix(_ from: Self, _ to: Self, _ progress: Double) -> Self {
            Self(x: `Timeline Tests`.mix(from.x, to.x, progress), y: `Timeline Tests`.mix(from.y, to.y, progress))
        }
    }

    @Suite
    struct Smoothing {
        @Test
        func `A track of pairs smooths to what two scalar tracks give, since smoothing needs only the interpolation`() {
            let times: [Rational] = [0, `Timeline Tests`.ratio(1, 3), 1, `Timeline Tests`.ratio(7, 2), 4]
            let xs: [Double] = [0, 2, -1, 2, 10]
            let ys: [Double] = [5, 4, 4, -3, 0.5]
            let pairs = Timeline.Track<Pair, Double>(ordered: (0..<5).map { Timeline.Track<Pair, Double>.Keyframe(at: times[$0], Pair(x: xs[$0], y: ys[$0])) })
            let x = `Timeline Tests`.Values(ordered: (0..<5).map { (times[$0], xs[$0]) })
            let y = `Timeline Tests`.Values(ordered: (0..<5).map { (times[$0], ys[$0]) })
            let instants = (-6...54).map { `Timeline Tests`.ratio($0, 12) }
            #expect(instants.allSatisfy { pairs.smooth(at: $0, interpolating: Pair.mix) == Pair(x: x.smooth(at: $0), y: y.smooth(at: $0)) })
        }

        @Test
        func `A smooth curve is the Hermite cubic with each keyframe's slope that of its neighbours`() {
            let keys: [(Rational, Double)] = [(0, 1), (1, 3), (3, 2), (4, 10), (6, -2)]
            let track = `Timeline Tests`.Values(ordered: keys)
            func slope(_ index: Int) -> Double {
                let (low, high) = (Swift.max(index - 1, keys.startIndex), Swift.min(index + 1, keys.endIndex - 1))
                return (keys[high].1 - keys[low].1) / (keys[high].0 - keys[low].0).approximation(as: Double.self)
            }
            keys.indices.dropLast().forEach { index in
                let (from, to) = (keys[index], keys[index + 1])
                let span = (to.0 - from.0).approximation(as: Double.self)
                (1..<16).forEach { step in
                    let t = Double(step) / 16
                    let (t2, t3) = (t * t, t * t * t)
                    let hermite =
                        (2 * t3 - 3 * t2 + 1) * from.1 + (t3 - 2 * t2 + t) * slope(index) * span
                        + (-2 * t3 + 3 * t2) * to.1 + (t3 - t2) * slope(index + 1) * span
                    let time = from.0 + (to.0 - from.0) * `Timeline Tests`.ratio(step, 16)
                    #expect(abs(track.smooth(at: time) - hermite) < 1e-13)
                }
            }
        }

        @Test
        func `Smoothing fails with the interpolation's typed failure, and follows the tail after the last keyframe`() throws {
            let track = `Timeline Tests`.Values(ordered: [Keyframe(at: 0, 0), Keyframe(at: 1, 10)], tail: .init(toward: 20) { $0 })
            func refuse(_ from: Double, _ to: Double, _ progress: Double) throws(Failure) -> Double { throw Failure() }
            #expect(throws: Failure()) { try track.smooth(at: `Timeline Tests`.ratio(1, 2), interpolating: refuse) }
            #expect(try track.smooth(at: 1, interpolating: refuse) == 10)
            #expect(track.smooth(at: `Timeline Tests`.ratio(3, 2)) == 15)
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Jitter {
        fileprivate static let key = Threefry.Key(0x0123_4567_89AB_CDEF, 0xFEDC_BA98_7654_3210)

        @Test
        func `A key's weights are pinned: one plus the spread times the draw in 1024ths from minus to plus one`() {
            let jitter = Timeline.Jitter(key: Self.key, spread: `Timeline Tests`.ratio(1, 2))
            let expected: [(Int, Int)] = [(711, 1024), (1125, 1024), (453, 512), (35, 32), (599, 512), (747, 1024), (617, 1024)]
            #expect((0...6).allSatisfy { jitter.weight(at: UInt64($0)) == `Timeline Tests`.ratio(expected[$0].0, expected[$0].1) })
            #expect(Array(jitter.prefix(4)) == (1...4).map { jitter.weight(at: UInt64($0)) })
            let instants = Timeline.instants(5, from: 0, to: 2, weights: jitter)
            #expect(instants == [0, `Timeline Tests`.ratio(2250, 4349), `Timeline Tests`.ratio(4062, 4349), `Timeline Tests`.ratio(6302, 4349), 2])
        }

        @Test
        func `A weight takes the keyed unit draw down to a multiple of 1/1024, on its own stream`() {
            for stream in [UInt64(0), 3] {
                let spread = `Timeline Tests`.ratio(3, 4)
                let jitter = Timeline.Jitter(key: Self.key, spread: spread, stream: stream)
                #expect(
                    (UInt64(0)..<256).allSatisfy { index in
                        let drawn = Threefry.unit(key: Self.key, stream: stream, index: index, as: Double.self)
                        let steps = Swift.min(Int((drawn * 1024).rounded(.down)), 1023)
                        return jitter.weight(at: index) == 1 + spread * `Timeline Tests`.ratio(2 * steps - 1024, 1024)
                    }
                )
            }
            let other = Timeline.Jitter(key: Self.key, spread: `Timeline Tests`.ratio(1, 2), stream: 1)
            #expect((1...8).map { other.weight(at: UInt64($0)) } != (1...8).map { Timeline.Jitter(key: Self.key, spread: `Timeline Tests`.ratio(1, 2)).weight(at: UInt64($0)) })
        }

        @Test
        func `Weights stay within the spread of one, and no spread is equal weights`() {
            let spread = `Timeline Tests`.ratio(2, 5)
            let jitter = Timeline.Jitter(key: Threefry.Key(7, 9), spread: spread)
            #expect(jitter.prefix(500).allSatisfy { $0 >= 1 - spread && $0 < 1 + spread })
            #expect(Timeline.Jitter(key: Threefry.Key(7, 9), spread: 0).prefix(50).allSatisfy { $0 == 1 })
            #expect(Timeline.Jitter(key: Threefry.Key(7, 9), spread: 1).prefix(500).allSatisfy { $0 >= 0 })
        }
    }
}

extension `Timeline Tests` {
    @Suite
    struct Series {
        @Test
        func `The count at an instant is the events at or before it`() {
            let series = Timeline.Series(ordered: [1, 2, 2, 3, `Timeline Tests`.ratio(7, 2), 5])
            let instants = (-4...30).map { `Timeline Tests`.ratio($0, 4) }
            #expect(instants.allSatisfy { time in series.count(at: time) == Cardinal(UInt(series.instants.filter { $0 <= time }.count)) })
            #expect(series.count(at: 0) == .zero && series.count(at: 2) == Cardinal(UInt(3)) && series.count(at: 99) == Cardinal(UInt(6)))
            #expect(Timeline.Series(ordered: []).count(at: 1) == .zero)
        }

        @Test
        func `A series by weights has the instants of the stagger`() {
            let jitter = Timeline.Jitter(key: Threefry.Key(1, 2), spread: `Timeline Tests`.ratio(1, 2))
            let series = Timeline.Series(12, from: 1, to: 4, weights: jitter)
            #expect(series.instants == Timeline.instants(12, from: 1, to: 4, weights: jitter))
            #expect(series.count(at: 4) == Cardinal(UInt(12)) && series.count(at: `Timeline Tests`.ratio(99, 100)) == .zero)
        }

        @Test
        func `Two steps on a loop of two blinks is a square wave: on for one blink, off for the next`() throws {
            let blink = `Timeline Tests`.ratio(1, 2)
            let wave = Timeline.Track<Bool, Double>.steps([(0, true), (blink, false)])
            let loop = try Timeline.Loop(period: 2 * blink)
            (0...80).forEach { eighth in
                let lit = wave.value(at: `Timeline Tests`.ratio(eighth, 8), looping: loop) { from, _, _ in from }
                #expect(lit == (eighth / 4).isMultiple(of: 2))
            }
            #expect(wave.value(at: -1, looping: loop) { from, _, _ in from })
        }
    }
}
