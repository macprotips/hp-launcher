import SwiftUI

/// The gold pill used for Play and Set Up.
struct CandleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Candle(configuration: configuration) }

    private struct Candle: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .labelStyle(Tight())
                .foregroundStyle(Color(red: 0.16, green: 0.11, blue: 0.05))
                .frame(minWidth: 132)
                .padding(.horizontal, 22)
                .frame(height: 42)
                .background {
                    Capsule().fill(LinearGradient(colors: [Theme.candle, Theme.gold], startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.5))
                        .brightness(hovering ? 0.05 : 0)
                }
                .shadow(color: Theme.candle.opacity(hovering ? 0.35 : 0.18), radius: hovering ? 16 : 10, y: 2)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(enabled ? 1 : 0.45)
                .animation(.easeOut(duration: 0.15), value: hovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
                .onHover { hovering = $0 && enabled }
        }
    }

    private struct Tight: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 8) { configuration.icon.imageScale(.small); configuration.title }
        }
    }
}
