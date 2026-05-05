import SwiftUI

// All design tokens extracted from the Sketch file (4 variants: dark/light × timeline/editor).
enum AppTheme {

    // MARK: - Accent
    static let accent = Color(hex: "FF5C00")

    // MARK: - Clip colors (consistent across dark and light themes)
    static let clipPink   = Color(hex: "E83C80")
    static let clipGreen  = Color(hex: "3DC870")
    static let clipTan    = Color(hex: "C87838")
    static let clipBlue   = Color(hex: "4868CC")
    static let clipSalmon = Color(hex: "DC6060")
    static let clipColors: [Color] = [clipPink, clipGreen, clipTan, clipBlue, clipSalmon]

    // MARK: - Dark theme
    enum Dark {
        static let bgPrimary    = Color(hex: "18181C")   // main canvas + transport bar
        static let bgSecondary  = Color(hex: "222228")   // track header column
        static let bgTrackRow   = Color(hex: "1E1E24")   // alternating track row tint
        static let border       = Color(hex: "333340")
        static let textPrimary  = Color.white
        static let textSecondary = Color(hex: "888899")
        static let editorBg     = Color(hex: "16161A")   // editor panel background
        static let waveformBg   = Color(hex: "0F0F14")   // waveform display area
        static let waveformLine = Color(hex: "3DC870")   // green waveform in editor
    }

    // MARK: - Light theme
    enum Light {
        static let bgPrimary    = Color(hex: "EBEBEF")
        static let bgSecondary  = Color(hex: "DCDCE4")
        static let bgTrackRow   = Color(hex: "E4E4EC")
        static let border       = Color(hex: "C0C0CC")
        static let textPrimary  = Color(hex: "111118")
        static let textSecondary = Color(hex: "666677")
        static let editorBg     = Color(hex: "16161A")   // editor always dark
        static let waveformBg   = Color(hex: "0F0F14")
        static let waveformLine = Color(hex: "3DC870")
    }

    // MARK: - Layout constants
    enum Layout {
        static let trackHeaderWidth: CGFloat = 132
        static let trackHeight:      CGFloat = 64
        static let transportHeight:  CGFloat = 48
        static let clipCornerRadius: CGFloat = 8
        static let clipGap:          CGFloat = 4
        static let timeUnit:         CGFloat = 88    // pixels per timeline unit
        static let editorWidth:      CGFloat = 480
        static let editorHeight:     CGFloat = 220
        static let knobSize:         CGFloat = 64
        static let sliderHeight:     CGFloat = 80
        static let sliderCount:      Int     = 7
    }

    // MARK: - Typography
    enum Font {
        static let timer        = SwiftUI.Font.system(size: 15, weight: .medium, design: .monospaced)
        static let trackName    = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let label        = SwiftUI.Font.system(size: 10, weight: .regular)
        static let editorTitle  = SwiftUI.Font.system(size: 12, weight: .medium)
    }
}

// MARK: - Scheme-adaptive helpers
extension AppTheme {
    static func bg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.bgPrimary : Light.bgPrimary
    }
    static func bgSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.bgSecondary : Light.bgSecondary
    }
    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.border : Light.border
    }
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.textPrimary : Light.textPrimary
    }
    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Dark.textSecondary : Light.textSecondary
    }
}
