import SwiftUI
import XCTest
@testable import HP_Launcher

/// Draws the app icon: a castle on its hill, its spire crossing a full moon. Dark on light keeps it
/// readable down to menu size. Skipped unless HPL_ICON names the PNG to write; tools/make-icon.sh
/// turns that into AppIcon.icns.
@MainActor
final class IconRenderTests: XCTestCase {
    func testRenderIcon() throws {
        guard let output = ProcessInfo.processInfo.environment["HPL_ICON"] else { throw XCTSkip("Set HPL_ICON to render the icon.") }
        let renderer = ImageRenderer(content: IconArt().frame(width: 1024, height: 1024))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.nsImage?.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) }?.representation(using: .png, properties: [:]))
        try image.write(to: URL(filePath: output))
    }
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }

/// The standard macOS icon shape: an 824 point rounded square on a 1024 canvas, with a soft shadow.
private struct IconArt: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        Canvas { c, size in
            let w = size.width, h = size.height
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(stops: [.init(color: rgb(9, 10, 28), location: 0), .init(color: rgb(26, 28, 70), location: 0.5), .init(color: rgb(74, 58, 106), location: 0.8)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            for (x, y, r, a) in [(0.17, 0.18, 5.0, 0.8), (0.82, 0.14, 4.0, 0.6), (0.12, 0.55, 3.0, 0.35), (0.86, 0.62, 3.5, 0.45)] {
                c.fill(Path(ellipseIn: CGRect(x: w * x - r / 2, y: h * y - r / 2, width: r, height: r)), with: .color(rgb(255, 247, 230).opacity(a)))
            }
            drawArt(&c, size)
        }
        .frame(width: 824, height: 824)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 2))
        .shadow(color: .black.opacity(0.30), radius: 10, y: 10)
        .frame(width: 1024, height: 1024)
    }

    private func drawArt(_ c: inout GraphicsContext, _ size: CGSize) {
        let w = size.width
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * w, y: y * w) }
        func R(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> CGRect { CGRect(x: x0 * w, y: y0 * w, width: (x1 - x0) * w, height: (y1 - y0) * w) }

        let moon = P(0.56, 0.34), radius = 0.205 * w
        c.fill(Path(ellipseIn: CGRect(x: moon.x - radius * 2.6, y: moon.y - radius * 2.6, width: radius * 5.2, height: radius * 5.2)),
               with: .radialGradient(Gradient(colors: [rgb(222, 226, 255).opacity(0.34), .clear]), center: moon, startRadius: radius, endRadius: radius * 2.6))
        c.fill(Path(ellipseIn: CGRect(x: moon.x - radius, y: moon.y - radius, width: radius * 2, height: radius * 2)),
               with: .radialGradient(Gradient(colors: [rgb(255, 251, 236), rgb(236, 226, 198)]),
                                     center: P(0.50, 0.27), startRadius: 0, endRadius: radius * 1.6))
        var seas = c
        seas.addFilter(.blur(radius: w * 0.006))
        for (x, y, rx, ry) in [(0.625, 0.285, 0.042, 0.03), (0.665, 0.37, 0.028, 0.022), (0.60, 0.405, 0.022, 0.016), (0.535, 0.215, 0.02, 0.014)]
            as [(Double, Double, Double, Double)] {
            seas.fill(Path(ellipseIn: R(x - rx, y - ry, x + rx, y + ry)), with: .color(rgb(160, 150, 132).opacity(0.10)))
        }

        let stone = rgb(14, 14, 34)
        var hill = Path()
        hill.move(to: P(0, 0.80))
        hill.addCurve(to: P(1, 0.78), control1: P(0.30, 0.66), control2: P(0.72, 0.66))
        hill.addLine(to: P(1, 1)); hill.addLine(to: P(0, 1)); hill.closeSubpath()

        var castle = Path()
        func tower(_ x0: Double, _ x1: Double, top: Double, apex: Double) {
            castle.addRect(R(x0, top, x1, 0.80))
            castle.move(to: P(x0 - 0.008, top)); castle.addLine(to: P((x0 + x1) / 2, apex)); castle.addLine(to: P(x1 + 0.008, top)); castle.closeSubpath()
        }
        castle.addRect(R(0.33, 0.585, 0.67, 0.80))                       // hall
        for i in 0..<5 { castle.addRect(R(0.345 + Double(i) * 0.064, 0.565, 0.375 + Double(i) * 0.064, 0.59)) }   // battlements
        tower(0.455, 0.545, top: 0.40, apex: 0.245)                       // keep, its spire against the moon
        tower(0.30, 0.365, top: 0.50, apex: 0.415)
        tower(0.635, 0.695, top: 0.46, apex: 0.36)
        tower(0.225, 0.262, top: 0.60, apex: 0.545)
        c.fill(hill, with: .color(stone))
        c.fill(castle, with: .color(stone))

        var lit = Path()
        lit.addRoundedRect(in: R(0.489, 0.46, 0.511, 0.497), cornerSize: CGSize(width: 0.011 * w, height: 0.011 * w))
        lit.addRoundedRect(in: R(0.402, 0.645, 0.42, 0.678), cornerSize: CGSize(width: 0.009 * w, height: 0.009 * w))
        lit.addRoundedRect(in: R(0.58, 0.645, 0.598, 0.678), cornerSize: CGSize(width: 0.009 * w, height: 0.009 * w))
        lit.addRoundedRect(in: R(0.657, 0.525, 0.673, 0.553), cornerSize: CGSize(width: 0.008 * w, height: 0.008 * w))
        var glow = c
        glow.addFilter(.blur(radius: w * 0.012))
        glow.fill(lit, with: .color(Theme.candle.opacity(0.9)))
        c.fill(lit, with: .color(rgb(255, 210, 130)))

        var ridge = Path()
        ridge.move(to: P(0, 0.88))
        ridge.addCurve(to: P(1, 0.86), control1: P(0.35, 0.83), control2: P(0.65, 0.92))
        ridge.addLine(to: P(1, 1)); ridge.addLine(to: P(0, 1)); ridge.closeSubpath()
        c.fill(ridge, with: .color(rgb(7, 7, 18)))
    }
}
