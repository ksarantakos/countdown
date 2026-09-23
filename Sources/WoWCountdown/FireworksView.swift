import SwiftUI

/// Full-screen fireworks drawn analytically from time, with a gold banner.
/// With Reduce Motion, shows only a soft glow and the banner fading in and out.
struct FireworksView: View {
    let start: Date
    let duration: TimeInterval
    let title: String
    let subtitle: String
    let reduceMotion: Bool
    private let bursts: [Burst]

    init(start: Date, duration: TimeInterval, seed: UInt64, title: String, subtitle: String, reduceMotion: Bool) {
        self.start = start
        self.duration = duration
        self.title = title
        self.subtitle = subtitle
        self.reduceMotion = reduceMotion
        var rng = SplitMix64(seed: seed)
        bursts = Burst.schedule(over: duration - 3.5, rng: &rng)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            ZStack {
                // Darkening scrim so the show reads over busy windows.
                RadialGradient(colors: [.black.opacity(0.35), .black.opacity(0.7)], center: .center, startRadius: 100, endRadius: 1400)
                    .opacity(scrim(t))
                if reduceMotion {
                    RadialGradient(colors: [Theme.gold400.opacity(0.35 * envelope(t)), .clear], center: .center, startRadius: 0, endRadius: 600)
                } else {
                    Canvas { context, size in draw(in: &context, size: size, t: t) }
                }
                banner(opacity: envelope(t))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func scrim(_ t: Double) -> Double {
        min(1, max(0, t / 0.6), max(0, (duration - t) / 1.5))
    }

    /// Fades in over the first 1.5 s and out over the last 2 s.
    private func envelope(_ t: Double) -> Double {
        min(1, max(0, (t - 0.5) / 1.0), max(0, (duration - 0.5 - t) / 2.0))
    }

    private func banner(opacity: Double) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(Theme.display(96, weight: .black))
                .tracking(4)
                .foregroundStyle(Theme.goldLeaf)
                .shadow(color: Theme.gold600.opacity(0.8), radius: 18)
                .shadow(color: .black.opacity(0.7), radius: 2, y: 3)
            Ornament(width: 360)
            Text(subtitle)
                .font(Theme.label(24, weight: .semibold))
                .tracking(6)
                .foregroundStyle(Theme.beige200)
                .shadow(color: .black.opacity(0.8), radius: 3, y: 2)
        }
        .opacity(opacity)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, t: Double) {
        context.blendMode = .plusLighter
        let scale = min(size.width, size.height) / 700
        for burst in bursts {
            let origin = CGPoint(x: burst.origin.x * size.width, y: burst.origin.y * size.height)
            let rocketAge = t - burst.launch
            if rocketAge >= 0, rocketAge < Burst.ascent {
                let p = 1 - pow(1 - rocketAge / Burst.ascent, 2)
                for trail in 0..<5 {
                    let q = max(0, p - Double(trail) * 0.03)
                    let x = burst.launchX * size.width + (origin.x - burst.launchX * size.width) * q
                    let y = size.height * 1.02 + (origin.y - size.height * 1.02) * q
                    let r = (2.2 - Double(trail) * 0.35) * scale
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(Theme.gold200.opacity(1 - Double(trail) * 0.18)))
                }
            }

            let age = rocketAge - Burst.ascent
            guard age >= 0, age < burst.life else { continue }
            if age < 0.3 {
                let r = 90 * scale * (0.5 + age * 2)
                context.fill(Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: 2 * r, height: 2 * r)),
                             with: .radialGradient(Gradient(colors: [burst.color.opacity(0.5 * (1 - age / 0.3)), .clear]),
                                                   center: origin, startRadius: 0, endRadius: r))
            }
            let fade = pow(1 - age / burst.life, 1.6)
            for (index, particle) in burst.particles.enumerated() {
                let color = index.isMultiple(of: 3) ? burst.accent : burst.color
                let twinkle = age > burst.life * 0.5 ? 0.6 + 0.4 * sin(age * 38 + Double(index)) : 1
                for trail in 0..<3 {
                    let a = max(0, age - Double(trail) * 0.045)
                    let spread = particle.speed * scale * (1 - exp(-2.4 * a)) / 2.4
                    let x = origin.x + cos(particle.angle) * spread
                    let y = origin.y + sin(particle.angle) * spread + 0.5 * 70 * scale * a * a
                    let r = (2.2 - Double(trail) * 0.55) * scale
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(color.opacity(fade * twinkle * (1 - Double(trail) * 0.35))))
                }
            }
        }
    }
}

private struct Burst {
    static let ascent = 0.85
    static let palette: [Color] = [Theme.gold300, Theme.beige200, Theme.teal200, Theme.gold400, Color(hex: 0xB58CFF), Color(hex: 0xFF8A3D)]

    struct Particle {
        let angle: Double
        let speed: Double
    }

    let launch: Double
    let origin: CGPoint  // unit coordinates, y down
    let launchX: Double
    let color: Color
    let accent: Color
    let life: Double
    let particles: [Particle]

    static func schedule(over span: Double, rng: inout SplitMix64) -> [Burst] {
        var launches = (0..<20).map { Double($0) * span * 0.75 / 20 + .random(in: 0...0.3, using: &rng) }
        launches += (0..<10).map { _ in span * 0.8 + .random(in: 0...0.8, using: &rng) }  // finale
        return launches.map { launch in
            let x = Double.random(in: 0.08...0.92, using: &rng)
            let count = Int.random(in: 90...140, using: &rng)
            let base = Double.random(in: 380...560, using: &rng)
            let ring = Bool.random(using: &rng)
            let particles = (0..<count).map { i in
                Particle(
                    angle: 2 * .pi * Double(i) / Double(count) + .random(in: -0.04...0.04, using: &rng),
                    speed: ring ? base : base * .random(in: 0.35...1, using: &rng)
                )
            }
            return Burst(
                launch: launch,
                origin: CGPoint(x: x, y: .random(in: 0.15...0.45, using: &rng)),
                launchX: x + .random(in: -0.06...0.06, using: &rng),
                color: palette.randomElement(using: &rng)!,
                accent: palette.randomElement(using: &rng)!,
                life: .random(in: 1.8...2.6, using: &rng),
                particles: particles
            )
        }
    }
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
