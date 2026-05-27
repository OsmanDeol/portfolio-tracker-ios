import SwiftUI

// MARK: - Color palette (for use as Color.appXxx)

extension Color {
    static let appBackground = Color(hex: "#0d1117")
    static let appSurface    = Color(hex: "#161b22")
    static let appBorder     = Color(hex: "#30363d")
    static let appText       = Color(hex: "#e6edf3")
    static let appSubtext    = Color(hex: "#8b949e")
    static let appAccent     = Color(hex: "#58a6ff")
    static let appGain       = Color(hex: "#3fb950")
    static let appLoss       = Color(hex: "#f85149")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - ShapeStyle extensions
// These enable dot-syntax inside .foregroundStyle(.appXxx) / .tint(.appXxx)

extension ShapeStyle where Self == Color {
    static var appBackground: Color { Color(hex: "#0d1117") }
    static var appSurface:    Color { Color(hex: "#161b22") }
    static var appBorder:     Color { Color(hex: "#30363d") }
    static var appText:       Color { Color(hex: "#e6edf3") }
    static var appSubtext:    Color { Color(hex: "#8b949e") }
    static var appAccent:     Color { Color(hex: "#58a6ff") }
    static var appGain:       Color { Color(hex: "#3fb950") }
    static var appLoss:       Color { Color(hex: "#f85149") }
}

// MARK: - Formatting helpers

extension Double {
    var currency: String {
        let f = NumberFormatter()
        f.numberStyle        = .currency
        f.currencySymbol     = "$"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var pct: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }

    var compact: String {
        switch abs(self) {
        case 1_000_000_000...: return String(format: "$%.2fB", self / 1_000_000_000)
        case 1_000_000...:     return String(format: "$%.2fM", self / 1_000_000)
        case 1_000...:         return String(format: "$%.1fK", self / 1_000)
        default:               return self.currency
        }
    }

    var gainColor: Color { self >= 0 ? .appGain : .appLoss }
}

// MARK: - Card style modifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
