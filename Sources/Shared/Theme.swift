import CoreText
import SwiftUI

/// Palette and type from the WoW Forever site: teal disc glow, bronze frame, carved cream capitals.
/// Fonts are open-license stand-ins: Cinzel (headings) and Open Sans (the site's body font).
enum Theme {
    // Gold
    static let gold200 = Color(hex: 0xFFF7C6)
    static let gold300 = Color(hex: 0xFFEC71)
    static let gold400 = Color(hex: 0xFFD254)
    static let gold600 = Color(hex: 0xC76700)
    // Beige / bronze
    static let beige200 = Color(hex: 0xF3EEE2)
    static let beige300 = Color(hex: 0xEBDEC2)
    static let beige400 = Color(hex: 0xB1997F)
    static let beige500 = Color(hex: 0x82705B)
    static let beige600 = Color(hex: 0x504137)
    static let beige700 = Color(hex: 0x352D25)
    // Teal
    static let teal200 = Color(hex: 0x00AFD7)
    static let teal400 = Color(hex: 0x007EA6)
    static let teal600 = Color(hex: 0x114F72)
    static let teal700 = Color(hex: 0x07324A)
    static let teal800 = Color(hex: 0x011C2B)
    static let sectionTop = Color(hex: 0x063149)
    static let sectionBottom = Color(hex: 0x017CAA)

    /// Carved cream lettering, lit from above.
    static let carved = LinearGradient(colors: [beige200, beige300, beige400], startPoint: .top, endPoint: .bottom)
    static let bronze = LinearGradient(colors: [beige300, beige400, beige600], startPoint: .top, endPoint: .bottom)
    static let goldLeaf = LinearGradient(colors: [gold200, gold400, gold600], startPoint: .top, endPoint: .bottom)

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Fonts.registerOnce
        return .custom("Cinzel", size: size).weight(weight)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Fonts.registerOnce
        return .custom("Open Sans", size: size).weight(weight)
    }
}

enum Fonts {
    /// Registers the bundled fonts for this process (app or widget extension).
    static let registerOnce: Void = {
        for name in ["Cinzel", "OpenSans"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("WoWCountdown: missing bundled font \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                print("WoWCountdown: failed to register \(name): \(String(describing: error?.takeRetainedValue()))")
            }
        }
    }()
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A small diamond stud, echoing the points of the medallion frame.
struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

/// ——◆—— divider.
struct Ornament: View {
    var width: CGFloat
    var body: some View {
        HStack(spacing: 5) {
            LinearGradient(colors: [.clear, Theme.beige400], startPoint: .leading, endPoint: .trailing).frame(height: 1)
            Diamond().fill(Theme.goldLeaf).frame(width: 6, height: 6)
            LinearGradient(colors: [Theme.beige400, .clear], startPoint: .leading, endPoint: .trailing).frame(height: 1)
        }
        .frame(width: width)
    }
}
