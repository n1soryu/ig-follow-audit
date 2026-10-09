import SwiftUI

/// Colours shared with the app icon.
enum Theme {
    static let violet = Color(red: 0x7B / 255, green: 0x4D / 255, blue: 0xFF / 255)
    static let pink = Color(red: 0xE5 / 255, green: 0x39 / 255, blue: 0x7A / 255)
    static let orange = Color(red: 0xFF / 255, green: 0x9A / 255, blue: 0x3D / 255)

    static let accent = pink
    static let gradient = LinearGradient(
        colors: [violet, pink, orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Soft colour glows behind the welcome screen.
struct Backdrop: View {
    var body: some View {
        ZStack {
            glow(Theme.violet, radius: 420).offset(x: -320, y: -240)
            glow(Theme.pink, radius: 380).offset(x: 340, y: -160)
            glow(Theme.orange, radius: 360).offset(x: 160, y: 320)
        }
        .opacity(0.3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // A radial gradient rather than a blurred circle: same look, far cheaper to draw.
    private func glow(_ color: Color, radius: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
    }
}

/// A round avatar with the username's initial, coloured consistently per username.
struct Avatar: View {
    let username: String
    var size: CGFloat = 30

    private var hue: Double {
        // Stable across launches, unlike `hashValue`.
        let hash = username.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) }
        return Double(abs(hash % 360)) / 360
    }

    private var initial: String {
        username.first { $0.isLetter || $0.isNumber }.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.5, brightness: 0.9),
                    Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 0.72),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}

/// A slim gradient progress bar.
struct GradientProgressBar: View {
    let fraction: Double
    var width: CGFloat = 180

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.quaternary)
            Capsule()
                .fill(Theme.gradient)
                .frame(width: max(0, min(1, fraction)) * width)
        }
        .frame(width: width, height: 6)
        .animation(.spring(duration: 0.4), value: fraction)
    }
}
