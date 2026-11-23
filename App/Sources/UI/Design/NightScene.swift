import SwiftUI

/// The night landscape behind each game, drawn back to front: sky, mountains, castle, the year's
/// scene, two ridges. Each layer overlaps the one behind it so nothing floats. See docs/Design.md.
struct NightScene: View {
    let game: GameID

    var body: some View {
        let palette = ScenePalette(game)
        // Separate layers so only the twinkling stars redraw each frame.
        ZStack {
            Canvas { context, size in
                drawSky(&context, size, palette)
                drawStars(&context, size)
            }
            TwinklingStars(moon: CGPoint(x: Self.moonX, y: Self.moonY))
            Canvas { context, size in
                drawMoon(&context, size, palette)
                drawLandscape(&context, size, palette)
            }
        }
        .animation(.easeInOut(duration: 0.7), value: game)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var moonPhase: Double {
        switch game { case .hp1: 0.28; case .hp2: 0.55; case .hp3: 1.0 }
    }

    private static let moonX = 0.80, moonY = 0.22

    private func drawSky(_ c: inout GraphicsContext, _ size: CGSize, _ p: ScenePalette) {
        let rect = CGRect(origin: .zero, size: size)
        c.fill(Path(rect), with: .linearGradient(Gradient(stops: [
            .init(color: p.zenith, location: 0), .init(color: p.mid, location: 0.55), .init(color: p.horizon, location: 1),
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    private func drawStars(_ c: inout GraphicsContext, _ size: CGSize) {
        var seed: UInt64 = 0x5EED_0F_5747
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max)
        }
        for _ in 0..<220 {
            let y = pow(next(), 1.6) * size.height * 0.7   // denser high in the sky
            let x = next() * size.width
            let r = 0.5 + pow(next(), 3) * 1.6
            let a = (0.25 + next() * 0.6) * (1 - y / (size.height * 0.75))
            c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(a)))
        }
    }

    private func drawMoon(_ c: inout GraphicsContext, _ size: CGSize, _ p: ScenePalette) {
        let radius = min(size.width, size.height) * 0.055
        let center = CGPoint(x: size.width * Self.moonX, y: size.height * Self.moonY)
        let disk = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let light = Color(red: 0.97, green: 0.95, blue: 0.89)
        // A wide soft halo and a tighter glow, both stronger the fuller the moon.
        c.fill(Path(ellipseIn: disk.insetBy(dx: -radius * 4, dy: -radius * 4)),
               with: .radialGradient(Gradient(colors: [p.moonGlow.opacity(0.22 * moonPhase + 0.05), .clear]),
                                     center: center, startRadius: radius, endRadius: radius * 5))
        c.fill(Path(ellipseIn: disk.insetBy(dx: -radius * 0.8, dy: -radius * 0.8)),
               with: .radialGradient(Gradient(colors: [light.opacity(0.2 * moonPhase * moonPhase), .clear]),
                                     center: center, startRadius: radius * 0.9, endRadius: radius * 1.8))
        // Earthshine: the unlit part of a crescent glows faintly.
        if moonPhase < 0.4 { c.fill(Path(ellipseIn: disk), with: .color(light.opacity(0.025))) }
        // The lit part: a shaded disk with faint seas, minus a shifted disk for the phase.
        c.drawLayer { layer in
            layer.fill(Path(ellipseIn: disk), with: .radialGradient(
                Gradient(colors: [light, Color(red: 0.90, green: 0.86, blue: 0.76)]),
                center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3), startRadius: 0, endRadius: radius * 1.5))
            var seas = layer
            seas.addFilter(.blur(radius: radius * 0.06))
            for (x, y, rx, ry, a) in [(0.28, -0.22, 0.30, 0.24, 0.10), (0.38, 0.22, 0.22, 0.18, 0.08), (-0.05, 0.05, 0.16, 0.20, 0.07),
                                       (0.08, -0.42, 0.14, 0.10, 0.06), (-0.30, 0.40, 0.18, 0.12, 0.05)] as [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] {
                let sea = CGRect(x: center.x + (x - rx) * radius, y: center.y + (y - ry) * radius, width: rx * 2 * radius, height: ry * 2 * radius)
                seas.fill(Path(ellipseIn: sea),
                          with: .color(Color(red: 0.55, green: 0.52, blue: 0.48).opacity(a)))
            }
            if moonPhase < 1 {
                layer.blendMode = .destinationOut
                let shift = radius * 2 * moonPhase
                var cut = layer
                cut.addFilter(.blur(radius: radius * 0.03))   // a soft terminator, not a hard edge
                cut.fill(Path(ellipseIn: disk.offsetBy(dx: -shift - radius * 0.05, dy: -radius * 0.06)), with: .color(.black))
            }
        }
    }

    // MARK: Landscape

    /// A smooth ground line through points given as fractions of the window, filled down to the bottom.
    private func ground(_ points: [(CGFloat, CGFloat)], _ size: CGSize) -> Path {
        let pts = points.map { CGPoint(x: $0.0 * size.width, y: $0.1 * size.height) }
        var path = Path()
        path.move(to: CGPoint(x: pts[0].x, y: size.height + 1))
        path.addLine(to: pts[0])
        for i in 1..<pts.count {
            path.addQuadCurve(to: CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2), control: pts[i - 1])
        }
        path.addLine(to: pts[pts.count - 1])
        path.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: size.height + 1))
        path.closeSubpath()
        return path
    }

    private func drawLandscape(_ c: inout GraphicsContext, _ size: CGSize, _ p: ScenePalette) {
        let w = size.width, h = size.height, s = h / 660
        let distant = p.farHill.mix(with: p.horizon, by: 0.38)
        let middle = p.farHill.mix(with: p.nearHill, by: 0.6)

        // Distant mountains, pale with haze.
        c.fill(ground([(-0.02, 0.66), (0.08, 0.61), (0.18, 0.645), (0.30, 0.60), (0.42, 0.65), (0.52, 0.63), (0.62, 0.60),
                       (0.74, 0.585), (0.86, 0.61), (1.02, 0.60)], size), with: .color(distant))

        // The castle on its hill, one silhouette: the towers run down into the hill.
        let hill = ground([(0.46, 0.90), (0.55, 0.74), (0.61, 0.66), (0.66, 0.632), (0.72, 0.625), (0.80, 0.628),
                           (0.86, 0.645), (0.93, 0.69), (1.02, 0.72)], size)
        let castle = Self.castlePaths(base: CGPoint(x: w * 0.72, y: h * 0.628), scale: h / 760)
        c.fill(hill, with: .color(p.farHill))
        c.fill(castle.shape, with: .color(p.farHill))
        drawWindows(&c, castle.lit, s)

        if game == .hp3 { drawLake(&c, size, p, hill: hill, castle: castle) }

        // Mist settling in the valley below the castle.
        c.fill(Path(CGRect(x: 0, y: h * 0.62, width: w, height: h * 0.2)), with: .linearGradient(
            Gradient(colors: [.clear, p.horizon.opacity(0.22), .clear]),
            startPoint: CGPoint(x: 0, y: h * 0.62), endPoint: CGPoint(x: 0, y: h * 0.82)))

        // The year's scene, then the middle ridge it stands on or disappears behind.
        var ridge: [(CGFloat, CGFloat)] = [(-0.02, 0.80), (0.12, 0.785), (0.26, 0.76), (0.40, 0.775), (0.55, 0.80),
                                           (0.70, 0.785), (0.85, 0.77), (1.02, 0.79)]
        switch game {
        case .hp1:
            drawTrain(&c, size, p, color: p.castle)
            // The far end of the viaduct runs into this rise.
            ridge = [(-0.02, 0.80), (0.14, 0.785), (0.30, 0.77), (0.42, 0.74), (0.50, 0.67), (0.56, 0.636), (0.62, 0.68),
                     (0.70, 0.76), (0.85, 0.775), (1.02, 0.79)]
        case .hp2:
            let willow = CGPoint(x: w * 0.40, y: h * 0.75)
            drawFlyingCar(&c, size, p, target: CGPoint(x: willow.x + 8 * s, y: willow.y - 110 * s))
            c.fill(Silhouette.willow(base: willow, scale: s), with: .color(middle))
            ridge = [(-0.02, 0.80), (0.14, 0.79), (0.27, 0.775), (0.34, 0.74), (0.40, 0.728), (0.46, 0.74), (0.56, 0.79),
                     (0.72, 0.785), (0.86, 0.77), (1.02, 0.79)]
        case .hp3:
            drawWraiths(&c, size, p)
        }
        c.fill(ground(ridge, size), with: .color(middle))

        // Near ridge, darkest, framing the title.
        c.fill(ground([(-0.02, 0.86), (0.20, 0.83), (0.40, 0.875), (0.58, 0.885), (0.75, 0.85), (0.90, 0.82), (1.02, 0.83)], size),
               with: .color(p.nearHill))
        // Darken the lower left so the title always reads.
        c.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(stops: [.init(color: p.nearHill.opacity(0.92), location: 0), .init(color: p.nearHill.opacity(0.7), location: 0.45),
                             .init(color: .clear, location: 1)]),
            center: CGPoint(x: w * 0.12, y: h * 1.02), startRadius: 0, endRadius: w * 0.62))
    }

    private func drawWindows(_ c: inout GraphicsContext, _ lit: Path, _ s: CGFloat) {
        var glow = c
        glow.addFilter(.blur(radius: 3 * s))
        glow.fill(lit, with: .color(Theme.candle.opacity(0.9)))
        c.fill(lit, with: .color(Theme.candle))
    }

    /// A small, generic castle: towers with pointed roofs and a handful of lit windows.
    /// The walls run well below `base` so the hill drawn with it always covers their feet.
    static func castlePaths(base: CGPoint, scale s: CGFloat) -> (shape: Path, lit: Path) {
        struct Tower { let x, width, height, roof: CGFloat }
        let towers = [Tower(x: -96, width: 16, height: 58, roof: 20), Tower(x: -70, width: 46, height: 34, roof: 0),
                      Tower(x: -30, width: 20, height: 92, roof: 30), Tower(x: -8, width: 64, height: 48, roof: 0),
                      Tower(x: 52, width: 14, height: 70, roof: 24), Tower(x: 70, width: 40, height: 30, roof: 0),
                      Tower(x: 108, width: 12, height: 50, roof: 16)]
        var shape = Path(), lit = Path()
        for t in towers {
            let left = base.x + t.x * s, top = base.y - t.height * s, width = t.width * s
            shape.addRect(CGRect(x: left, y: top, width: width, height: (t.height + 50) * s))
            if t.roof > 0 {
                shape.move(to: CGPoint(x: left - 2 * s, y: top))
                shape.addLine(to: CGPoint(x: left + width / 2, y: top - t.roof * s))
                shape.addLine(to: CGPoint(x: left + width + 2 * s, y: top))
                shape.closeSubpath()
            }
            if t.height > 45 {
                lit.addRect(CGRect(x: left + width / 2 - 1.2 * s, y: top + 12 * s, width: 2.4 * s, height: 4 * s))
            }
        }
        lit.addRect(CGRect(x: base.x + 6 * s, y: base.y - 30 * s, width: 2.4 * s, height: 3.6 * s))
        lit.addRect(CGRect(x: base.x + 28 * s, y: base.y - 30 * s, width: 2.4 * s, height: 3.6 * s))
        return (shape, lit)
    }

    // MARK: Year scenes

    /// Year I: a steam train crossing a stone viaduct toward the castle, smoke trailing back.
    private func drawTrain(_ c: inout GraphicsContext, _ size: CGSize, _ p: ScenePalette, color: Color) {
        let w = size.width, h = size.height, s = h / 660
        let deckY = h * 0.648, left = -w * 0.02, right = w * 0.545
        // One block of stone with the arches cut out; its piers run down behind the ridges.
        var viaduct = Path(CGRect(x: left, y: deckY, width: right - left, height: h - deckY + 2))
        let span = 46 * s
        var x = left + 4 * s
        while x + span < right {
            let arch = CGRect(x: x + 7 * s, y: deckY + 12 * s, width: span - 14 * s, height: h)
            viaduct.addPath(Path(roundedRect: arch, cornerRadii: RectangleCornerRadii(topLeading: arch.width / 2, topTrailing: arch.width / 2)))
            x += span
        }
        c.fill(viaduct, with: .color(p.farHill.mix(with: color, by: 0.55)), style: FillStyle(eoFill: true))
        c.fill(Path(CGRect(x: left, y: deckY - 1.5 * s, width: right - left, height: 1.5 * s)), with: .color(color))   // rails

        // The train on the rails, smoke trailing back from the chimney.
        let train = Silhouette.train(rail: CGPoint(x: w * 0.05, y: deckY - 1.5 * s), unit: 1.62 * s, carriages: 3)
        c.fill(train.body, with: .color(color))
        c.fill(train.lit, with: .color(Theme.candle.opacity(0.85)))
        var smoke = c
        smoke.addFilter(.blur(radius: 4 * s))
        for i in 0..<8 {
            let t = CGFloat(i), r = (8 + t * 5) * s
            smoke.fill(Path(ellipseIn: CGRect(x: train.chimney.x - r * 0.5 - t * 24 * s, y: train.chimney.y - 6 * s - t * 5 * s - r / 2,
                                              width: r * 1.4, height: r)),
                       with: .color(p.horizon.opacity(0.30 - Double(i) * 0.03)))
        }
    }

    /// Year II: the flying car diving straight at the willow, headlights on its branches.
    private func drawFlyingCar(_ c: inout GraphicsContext, _ size: CGSize, _ p: ScenePalette, target: CGPoint) {
        let w = size.width, h = size.height, s = h / 660
        let rect = CGRect(x: w * 0.17, y: h * 0.34, width: 68 * s, height: 33 * s)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let distance = hypot(target.x - center.x, target.y - center.y)
        var aimed = c
        aimed.translateBy(x: center.x, y: center.y)
        aimed.rotate(by: .radians(atan2(target.y - center.y, target.x - center.x)))
        aimed.translateBy(x: -center.x, y: -center.y)
        // Headlight beams reaching the tree.
        let reach = distance - rect.width / 2
        var beam = Path()
        beam.move(to: CGPoint(x: rect.maxX - 2 * s, y: rect.minY + rect.height * 0.5))
        beam.addLine(to: CGPoint(x: rect.maxX + reach, y: rect.midY - 30 * s))
        beam.addLine(to: CGPoint(x: rect.maxX + reach, y: rect.midY + 26 * s))
        beam.closeSubpath()
        aimed.fill(beam, with: .linearGradient(Gradient(colors: [Theme.candle.opacity(0.34), Theme.candle.opacity(0.08), .clear]),
                                               startPoint: CGPoint(x: rect.maxX, y: rect.midY), endPoint: CGPoint(x: rect.maxX + reach, y: rect.midY)))
        // Speed lines streaming off the back.
        for (i, dy) in [-5.0, 1.5, 7.0].enumerated() {
            let length = (70 - CGFloat(i) * 16) * s, y = rect.midY + dy * s
            aimed.stroke(Path { $0.move(to: CGPoint(x: rect.minX - 4 * s, y: y)); $0.addLine(to: CGPoint(x: rect.minX - 4 * s - length, y: y)) },
                         with: .linearGradient(Gradient(colors: [p.horizon.opacity(0.55), .clear]),
                                               startPoint: CGPoint(x: rect.minX, y: y), endPoint: CGPoint(x: rect.minX - length, y: y)),
                         style: StrokeStyle(lineWidth: 1.2 * s, lineCap: .round))
        }
        aimed.fill(Silhouette.vintageCar(.init(rect: rect)), with: .color(p.castle))
        let headlight = CGRect(x: rect.maxX - 4 * s, y: rect.minY + rect.height * 0.44, width: 3.5 * s, height: 3.5 * s)
        aimed.fill(Path(ellipseIn: headlight), with: .color(Theme.candle))
    }

    /// Year III: the castle and the moon reflected in a still lake.
    private func drawLake(_ c: inout GraphicsContext, _ size: CGSize, _ p: ScenePalette, hill: Path, castle: (shape: Path, lit: Path)) {
        let w = size.width, h = size.height, s = h / 660, waterline = h * 0.70
        let water = CGRect(x: 0, y: waterline, width: w, height: h - waterline)
        c.fill(Path(water), with: .linearGradient(Gradient(colors: [p.mid.mix(with: p.farHill, by: 0.45), p.farHill]),
                                                  startPoint: CGPoint(x: 0, y: waterline), endPoint: CGPoint(x: 0, y: h * 0.82)))
        var mirror = c
        mirror.clip(to: Path(water))
        mirror.opacity = 0.45
        mirror.translateBy(x: 0, y: waterline * 2); mirror.scaleBy(x: 1, y: -1)
        mirror.fill(hill, with: .color(p.farHill.mix(with: p.nearHill, by: 0.4)))
        mirror.fill(castle.shape, with: .color(p.farHill.mix(with: p.nearHill, by: 0.4)))
        mirror.fill(castle.lit, with: .color(Theme.candle.opacity(0.6)))
        // Moonlight as wavy ripples narrowing toward the shore, plus a faint swell elsewhere.
        func ripple(_ cx: CGFloat, _ y: CGFloat, _ width: CGFloat, _ phase: CGFloat, _ alpha: Double, _ line: CGFloat) {
            var path = Path()
            let steps = max(8, Int(width / (2 * s)))
            for i in 0...steps {
                let x = cx - width / 2 + width * CGFloat(i) / CGFloat(steps)
                let point = CGPoint(x: x, y: y + sin(x / (9 * s) + phase) * 1.1 * s)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            c.stroke(path, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(alpha), .clear]),
                                                 startPoint: CGPoint(x: cx - width / 2, y: y), endPoint: CGPoint(x: cx + width / 2, y: y)),
                     style: StrokeStyle(lineWidth: line, lineCap: .round))
        }
        let moonX = w * Self.moonX
        for i in 0..<10 {
            let t = CGFloat(i)
            ripple(moonX + (i % 2 == 0 ? 3 : -5) * s, waterline + (4 + t * 6.5) * s, (78 - t * 5.5) * s, t * 1.7, 0.42 - Double(i) * 0.032, 1.5 * s)
        }
        for (x, y, width) in [(0.62, 0.716, 0.08)] as [(CGFloat, CGFloat, CGFloat)] {
            ripple(w * x, h * y, w * width, x * 20, 0.07, 1 * s)
        }
        c.fill(Path(CGRect(x: 0, y: waterline, width: w, height: 1 * s)), with: .color(p.horizon.opacity(0.5)))   // far shore
    }

    /// Year III: tall hooded wraiths drifting low over the water.
    private func drawWraiths(_ c: inout GraphicsContext, _ size: CGSize, _ p: ScenePalette) {
        let w = size.width, h = size.height, s = h / 660
        for (i, spot) in [(0.40, 0.46, 1.0), (0.50, 0.52, 0.8), (0.31, 0.53, 0.7)].enumerated() {
            let height = 88 * s * spot.2
            let frame = Silhouette.Frame(rect: CGRect(x: w * spot.0, y: h * spot.1, width: height * 0.5, height: height))
            let wraith = Silhouette.wraith(frame)
            var figure = c
            figure.opacity = 0.92 - Double(i) * 0.12
            let shade = GraphicsContext.Shading.linearGradient(Gradient(colors: [p.castle, p.castle.opacity(0.15)]),
                                                               startPoint: frame.rect.origin, endPoint: CGPoint(x: frame.rect.minX, y: frame.rect.maxY))
            figure.fill(wraith, with: shade)
        }
    }
}

/// The brighter stars, twinkling slowly. Kept clear of the moon; still under Reduce Motion.
private struct TwinklingStars: View {
    let moon: CGPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star { let x, y, size, phase, speed, brightness: Double }
    private static let stars: [Star] = {
        var seed: UInt64 = 0x57A2_5EED
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max)
        }
        return (0..<34).map { _ in
            Star(x: next(), y: 0.03 + pow(next(), 1.3) * 0.40, size: 1.1 + pow(next(), 2) * 1.6,
                 phase: next() * .pi * 2, speed: 0.25 + next() * 0.6, brightness: 0.45 + next() * 0.5)
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                let moonPoint = CGPoint(x: moon.x * size.width, y: moon.y * size.height)
                let keepClear = min(size.width, size.height) * 0.055 * 5
                for star in Self.stars {
                    let point = CGPoint(x: star.x * size.width, y: star.y * size.height)
                    guard hypot(point.x - moonPoint.x, point.y - moonPoint.y) > keepClear else { continue }
                    let alpha = star.brightness * (0.6 + 0.4 * sin(time * star.speed + star.phase))
                    let glow = star.size * 3.5
                    c.fill(Path(ellipseIn: CGRect(x: point.x - glow, y: point.y - glow, width: glow * 2, height: glow * 2)),
                           with: .radialGradient(Gradient(colors: [.white.opacity(alpha * 0.22), .clear]), center: point, startRadius: 0, endRadius: glow))
                    c.fill(Path(ellipseIn: CGRect(x: point.x - star.size / 2, y: point.y - star.size / 2, width: star.size, height: star.size)),
                           with: .color(Color(red: 1, green: 0.97, blue: 0.9).opacity(alpha)))
                }
            }
        }
    }
}

/// Colours for one year's sky, tuned so the title always reads.
struct ScenePalette {
    let zenith, mid, horizon, farHill, nearHill, castle, moonGlow: Color

    init(_ game: GameID) {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
        switch game {
        case .hp1: // warm plum dusk
            zenith = rgb(14, 12, 24); mid = rgb(38, 24, 44); horizon = rgb(92, 52, 62)
            farHill = rgb(30, 20, 32); nearHill = rgb(12, 9, 15); castle = rgb(22, 15, 25); moonGlow = rgb(255, 214, 170)
        case .hp2: // deep teal
            zenith = rgb(7, 14, 22); mid = rgb(16, 38, 50); horizon = rgb(40, 86, 96)
            farHill = rgb(12, 27, 34); nearHill = rgb(5, 11, 15); castle = rgb(9, 20, 26); moonGlow = rgb(200, 236, 230)
        case .hp3: // cold indigo under a full moon
            zenith = rgb(8, 9, 24); mid = rgb(22, 26, 62); horizon = rgb(66, 74, 128)
            farHill = rgb(17, 19, 44); nearHill = rgb(7, 8, 19); castle = rgb(12, 13, 32); moonGlow = rgb(214, 222, 255)
        }
    }
}
