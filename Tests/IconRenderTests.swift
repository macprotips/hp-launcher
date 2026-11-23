import SwiftUI
import XCTest
@testable import HP_Launcher

/// Draws the app icon from the same night scene as the main window: a full moon over the castle.
/// Skipped unless HPL_ICON names the PNG to write; tools/make-icon.sh turns that into AppIcon.icns.
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

/// The standard macOS icon shape: an 824 point rounded square on a 1024 canvas, with a soft shadow.
private struct IconArt: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        Canvas { c, size in
            let w = size.width, h = size.height
            func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
            let hill = rgb(15, 16, 40), near = rgb(7, 8, 19)
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(stops: [.init(color: rgb(9, 10, 28), location: 0), .init(color: rgb(26, 30, 74), location: 0.55), .init(color: rgb(86, 78, 132), location: 1)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.86)))
            // Stars, sparse and fixed.
            for (x, y, r, a) in [(0.14, 0.16, 5.0, 0.9), (0.30, 0.09, 3.0, 0.7), (0.24, 0.33, 3.5, 0.6), (0.46, 0.20, 4.0, 0.8), (0.10, 0.42, 3.0, 0.5),
                                 (0.55, 0.08, 3.0, 0.6), (0.38, 0.40, 2.5, 0.45), (0.88, 0.44, 3.0, 0.5), (0.62, 0.36, 2.5, 0.4)] {
                c.fill(Path(ellipseIn: CGRect(x: w * x - r / 2, y: h * y - r / 2, width: r, height: r)), with: .color(rgb(255, 247, 230).opacity(a)))
            }
            // The moon, with a wide halo.
            let moon = CGPoint(x: w * 0.70, y: h * 0.30), radius = w * 0.125
            c.fill(Path(ellipseIn: CGRect(x: moon.x - radius * 3.4, y: moon.y - radius * 3.4, width: radius * 6.8, height: radius * 6.8)),
                   with: .radialGradient(Gradient(colors: [rgb(214, 222, 255).opacity(0.34), .clear]), center: moon, startRadius: radius, endRadius: radius * 3.4))
            c.fill(Path(ellipseIn: CGRect(x: moon.x - radius, y: moon.y - radius, width: radius * 2, height: radius * 2)),
                   with: .radialGradient(Gradient(colors: [rgb(250, 245, 228), rgb(232, 221, 194)]),
                                         center: CGPoint(x: moon.x - radius * 0.3, y: moon.y - radius * 0.3), startRadius: 0, endRadius: radius * 1.5))
            // The castle on its hill, then a darker ridge in front.
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: h * 0.80))
            ground.addCurve(to: CGPoint(x: w, y: h * 0.74), control1: CGPoint(x: w * 0.30, y: h * 0.60), control2: CGPoint(x: w * 0.70, y: h * 0.62))
            ground.addLine(to: CGPoint(x: w, y: h)); ground.addLine(to: CGPoint(x: 0, y: h)); ground.closeSubpath()
            let castle = NightScene.castlePaths(base: CGPoint(x: w * 0.47, y: h * 0.672), scale: w / 330)
            c.fill(ground, with: .color(hill))
            c.fill(castle.shape, with: .color(hill))
            var glow = c
            glow.addFilter(.blur(radius: 9))
            glow.fill(castle.lit, with: .color(Theme.candle))
            c.fill(castle.lit, with: .color(Theme.candle))
            var ridge = Path()
            ridge.move(to: CGPoint(x: 0, y: h * 0.86))
            ridge.addCurve(to: CGPoint(x: w, y: h * 0.84), control1: CGPoint(x: w * 0.35, y: h * 0.80), control2: CGPoint(x: w * 0.65, y: h * 0.90))
            ridge.addLine(to: CGPoint(x: w, y: h)); ridge.addLine(to: CGPoint(x: 0, y: h)); ridge.closeSubpath()
            c.fill(ridge, with: .color(near))
        }
        .frame(width: 824, height: 824)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 2))
        .shadow(color: .black.opacity(0.30), radius: 10, y: 10)
        .frame(width: 1024, height: 1024)
    }
}
