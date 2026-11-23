import SwiftUI

/// Silhouettes for the night scenes. Most are drawn in a unit box (x right, y down) mapped into a
/// rectangle; the train and willow use their own units from a base point.
enum Silhouette {
    /// Maps unit coordinates into `rect`, optionally mirrored horizontally.
    struct Frame {
        let rect: CGRect
        var mirrored = false
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (mirrored ? 1 - x : x) * rect.width, y: rect.minY + y * rect.height)
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            let a = p(x, y), b = p(x + w, y + h)
            return CGRect(x: min(a.x, b.x), y: a.y, width: abs(b.x - a.x), height: b.y - a.y)
        }
        func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
            Path(ellipseIn: r(cx - rx, cy - ry, rx * 2, ry * 2))
        }
    }

    // MARK: Steam train

    /// A steam express heading right: carriages, tender, then a locomotive with a long boiler,
    /// tall chimney and three big coupled wheels. Drawn on the rails at `rail` (its left end),
    /// in units of `u` points. Returns the body, its lit windows and the top of the chimney.
    static func train(rail: CGPoint, unit u: CGFloat, carriages: Int) -> (body: Path, lit: Path, chimney: CGPoint) {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rail.x + x * u, y: rail.y - y * u) }
        func R(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(x: P(x0, 0).x, y: P(0, y1).y, width: (x1 - x0) * u, height: (y1 - y0) * u)
        }
        func wheel(_ x: CGFloat, _ r: CGFloat) -> Path { Path(ellipseIn: R(x - r, 0, x + r, 2 * r)) }
        var body = Path(), lit = Path()
        func add(_ piece: Path) { body = body.union(piece) }   // union, so overlaps never cut holes

        // Carriages, each with lit windows and a bogie at each end.
        var x: CGFloat = 0
        for _ in 0..<carriages {
            let roof = RectangleCornerRadii(topLeading: 5 * u, bottomLeading: u, bottomTrailing: u, topTrailing: 5 * u)
            add(Path(roundedRect: R(x, 6, x + 52, 24), cornerRadii: roof))
            for bogie in [x + 9, x + 43] {
                add(Path(R(bogie - 6, 3, bogie + 6, 6.5)))
                add(wheel(bogie - 3.2, 2.6)); add(wheel(bogie + 3.2, 2.6))
            }
            for i in 0..<9 { lit.addRect(R(x + 5 + CGFloat(i) * 5, 13.5, x + 7.6 + CGFloat(i) * 5, 19.5)) }
            add(Path(R(x + 52, 9, x + 55, 20)))   // gangway to the next vehicle
            x += 55
        }

        // Tender: a coal box on three wheels.
        add(Path(roundedRect: R(x, 6, x + 26, 21), cornerSize: CGSize(width: u, height: u)))
        add(Path(roundedRect: R(x + 3, 20, x + 23, 23), cornerSize: CGSize(width: 1.5 * u, height: 1.5 * u)))
        for t in [x + 5, x + 13, x + 21] { add(wheel(t, 3.6)) }
        add(Path(R(x + 26, 9, x + 28, 12)))
        x += 28

        // Locomotive, cab first.
        add(Path(R(x, 9.5, x + 14, 30)))                                                                           // cab
        add(Path(roundedRect: R(x - 1.5, 29, x + 15.5, 31.5), cornerSize: CGSize(width: u, height: u)))
        add(Path(R(x, 8.5, x + 60, 10)))                                                                           // running plate
        add(Path(roundedRect: R(x + 14, 10, x + 54, 21.5), cornerSize: CGSize(width: 3 * u, height: 3 * u)))       // boiler
        add(Path(roundedRect: R(x + 52, 9.5, x + 58, 22), cornerSize: CGSize(width: 2 * u, height: 2 * u)))        // smokebox
        add(Path(roundedRect: R(x + 30, 20, x + 35.5, 25), cornerSize: CGSize(width: 2.5 * u, height: 2.5 * u)))   // safety valve
        add(Path(R(x + 53.2, 21, x + 57, 27)))                                                                     // chimney
        add(Path(roundedRect: R(x + 52.4, 26, x + 57.8, 28.2), cornerSize: CGSize(width: 0.6 * u, height: 0.6 * u)))
        add(Path(R(x + 46, 5.5, x + 54, 10)))                                                                      // cylinder
        add(Path(R(x + 58, 5.5, x + 60.5, 10)))                                                                    // buffer beam
        add(Path(R(x + 60.5, 7, x + 62.5, 8.5)))                                                                   // buffer
        for d in [x + 12, x + 25, x + 38] { add(wheel(d, 6.2)) }                                                   // driving wheels under splashers
        add(Path(R(x + 12, 5.4, x + 38, 6.6)))                                                                     // coupling rod
        add(wheel(x + 49, 3)); add(wheel(x + 55.5, 3))                                                             // front bogie
        lit.addRect(R(x + 4, 21.5, x + 8, 25.5))                                                                   // firelit cab window
        return (body, lit, P(x + 55.1, 28))
    }

    // MARK: Vintage car

    /// A small rounded car of the 1950s and 60s, facing right, with its wheels.
    static func vintageCar(_ f: Frame) -> Path {
        var c = Path()
        c.move(to: f.p(0.02, 0.62))
        c.addCurve(to: f.p(0.20, 0.36), control1: f.p(0.02, 0.45), control2: f.p(0.10, 0.37))   // rear deck
        c.addLine(to: f.p(0.30, 0.34))
        c.addCurve(to: f.p(0.42, 0.06), control1: f.p(0.32, 0.18), control2: f.p(0.36, 0.08))   // raked rear window
        c.addLine(to: f.p(0.66, 0.05))
        c.addCurve(to: f.p(0.76, 0.33), control1: f.p(0.71, 0.08), control2: f.p(0.73, 0.20))
        c.addCurve(to: f.p(0.98, 0.46), control1: f.p(0.88, 0.34), control2: f.p(0.97, 0.38))   // bonnet
        c.addLine(to: f.p(0.98, 0.68)); c.addLine(to: f.p(0.02, 0.70)); c.closeSubpath()
        c.addPath(f.ellipse(0.22, 0.72, 0.085, 0.085 * f.rect.width / f.rect.height))
        c.addPath(f.ellipse(0.78, 0.72, 0.085, 0.085 * f.rect.width / f.rect.height))
        return c
    }

    // MARK: Whomping willow

    /// A gnarled willow with whip branches, one swung high. `base` is where the trunk meets the ground.
    static func willow(base: CGPoint, scale s: CGFloat) -> Path {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: base.x + x * s, y: base.y - y * s) }
        var tree = Path()
        func add(_ piece: Path) { tree = tree.union(piece) }   // union, so overlapping strokes never cut holes
        // Trunk, roots and a burr.
        add(taper(P(0, -6), P(-16, 20), P(16, 36), P(0, 58), 46 * s, 22 * s))
        add(taper(P(-6, 6), P(-20, 2), P(-32, -2), P(-44, -8), 18 * s, 3 * s))
        add(taper(P(6, 6), P(20, 3), P(32, -1), P(46, -8), 18 * s, 3 * s))
        add(taper(P(-14, 26), P(-24, 30), P(-26, 40), P(-22, 48), 8 * s, 2 * s))   // gnarled burr
        // Five limbs, each ending in whips that arc out and droop.
        let top = P(0, 54)
        let limbs: [(c1: CGPoint, c2: CGPoint, end: CGPoint, out: CGFloat)] = [
            (P(-14, 70), P(-40, 92), P(-70, 88), -1), (P(-8, 86), P(-22, 104), P(-30, 124), -1),
            (P(8, 90), P(4, 112), P(16, 128), 1), (P(16, 78), P(36, 100), P(58, 106), 1), (P(22, 64), P(56, 78), P(84, 72), 1),
        ]
        for (i, limb) in limbs.enumerated() {
            add(taper(top, limb.c1, limb.c2, limb.end, 17 * s, 6 * s))
            let e = limb.end, d = limb.out
            for k in 0..<2 {
                let reach = (64 + CGFloat(k) * 34 + CGFloat(i % 2) * 10) * s
                let rise = (24 - CGFloat(k) * 12) * s, drop = (30 + CGFloat(k) * 34) * s
                add(taper(e, CGPoint(x: e.x + d * reach * 0.35, y: e.y - rise), CGPoint(x: e.x + d * reach * 0.85, y: e.y - rise * 0.5),
                          CGPoint(x: e.x + d * reach, y: e.y + drop), 5 * s, 1 * s))
            }
        }
        // One whip swung high, mid-strike.
        let swing = limbs[4].end
        add(taper(swing, CGPoint(x: swing.x + 26 * s, y: swing.y - 56 * s), CGPoint(x: swing.x + 96 * s, y: swing.y - 76 * s),
                  CGPoint(x: swing.x + 134 * s, y: swing.y - 28 * s), 6 * s, 1 * s))
        return tree
    }

    /// A curved stroke that narrows from `w0` to `w1`, for trunks, limbs and whips.
    static func taper(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, _ w0: CGFloat, _ w1: CGFloat) -> Path {
        func at(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * u * a.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * b.x,
                           y: u * u * u * a.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * b.y)
        }
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...24 {
            let t = CGFloat(i) / 24, p = at(t), ahead = at(min(1, t + 0.01)), behind = at(max(0, t - 0.01))
            let dx = ahead.x - behind.x, dy = ahead.y - behind.y, length = max(hypot(dx, dy), 0.0001)
            let half = (w0 + (w1 - w0) * t) / 2
            left.append(CGPoint(x: p.x - dy / length * half, y: p.y + dx / length * half))
            right.append(CGPoint(x: p.x + dy / length * half, y: p.y - dx / length * half))
        }
        var path = Path()
        path.addLines(left + right.reversed())
        path.closeSubpath()
        return path
    }

    // MARK: Hooded wraith

    /// A tall hooded wraith, leaning forward, its cloak torn into long trailing strips.
    static func wraith(_ f: Frame) -> Path {
        var c = Path()
        c.move(to: f.p(0.55, 0.0))                                                     // hood peak
        c.addCurve(to: f.p(0.80, 0.16), control1: f.p(0.70, 0.01), control2: f.p(0.80, 0.08))
        c.addCurve(to: f.p(0.70, 0.40), control1: f.p(0.80, 0.24), control2: f.p(0.74, 0.30))
        c.addCurve(to: f.p(0.78, 0.72), control1: f.p(0.68, 0.52), control2: f.p(0.80, 0.60))
        let hem: [(CGFloat, CGFloat)] = [(0.70, 0.98), (0.62, 0.78), (0.52, 1.0), (0.44, 0.80), (0.33, 0.96), (0.27, 0.74),
                                         (0.12, 0.90), (0.16, 0.64)]
        for p in hem { c.addLine(to: f.p(p.0, p.1)) }
        c.addCurve(to: f.p(0.30, 0.20), control1: f.p(0.16, 0.44), control2: f.p(0.20, 0.30))
        c.addCurve(to: f.p(0.55, 0.0), control1: f.p(0.36, 0.08), control2: f.p(0.46, 0.0))
        c.closeSubpath()
        return c
    }
}
