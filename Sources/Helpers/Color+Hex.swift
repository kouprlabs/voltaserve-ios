import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let red, green, blue: Double
        switch hex.count {
        case 6: // RGB (24-bit)
            (red, green, blue) = (Double((int >> 16) & 0xFF), Double((int >> 8) & 0xFF), Double(int & 0xFF))
        case 8: // ARGB (32-bit)
            (red, green, blue) = (Double((int >> 16) & 0xFF), Double((int >> 8) & 0xFF), Double(int & 0xFF))
        default:
            (red, green, blue) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            opacity: 1.0
        )
    }

    func toHexString() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Format the RGB values into a hex string
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}