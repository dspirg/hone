import SwiftUI

enum Theme {
    // MARK: - Colors (backed by asset catalog dark variants)
    static let accent = Color("AccentColor")
    static let background = Color("AppBackground")
    static let surface = Color("CardBackground")
    static let surfaceElevated = Color("SurfaceElevated")
    static let borderSubtle = Color("BorderSubtle")
    static let successGreen = Color("SuccessGreen")
    static let destructiveRed = Color("DestructiveRed")

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
}
