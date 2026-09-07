//
//  Theme.swift
//  Dozy
//

import SwiftUI
import UIKit

// MARK: - Spacing

/// The only spacing values the app uses. Anything in between is a bug, not a decision.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Layout

enum Layout {
    /// Apple's minimum comfortable hit area; every control is at least this tall.
    static let minTouchTarget: CGFloat = 44

    static let cardCorner: CGFloat = 20
    static let controlCorner: CGFloat = 14
    static let border: CGFloat = 1

    static let statusIcon: CGFloat = 28
    static let medicationDot: CGFloat = 10
    static let colorSwatch: CGFloat = 44
}

// MARK: - Typography

/// Named text styles, so no view reaches for a font weight of its own.
enum Typography {
    static let itemTitle = Font.headline
    static let itemDetail = Font.subheadline
    static let time = Font.title3.weight(.semibold)
    static let meta = Font.footnote
    static let control = Font.subheadline.weight(.semibold)
    static let sectionTitle = Font.subheadline.weight(.semibold)
}

// MARK: - Colors

/// Color carries meaning only: the state of a dose, and the color the user gave a medication.
/// Everything else is a neutral surface or neutral text.
enum Palette {
    /// The flat page background behind every screen.
    static let surface = adaptive(light: UIColor(white: 0.95, alpha: 1),
                                  dark: UIColor(white: 0.07, alpha: 1))

    static let card = adaptive(light: .white, dark: UIColor(white: 0.14, alpha: 1))
    static let cardBorder = adaptive(light: UIColor(white: 0, alpha: 0.08),
                                     dark: UIColor(white: 1, alpha: 0.12))
    static let shadow = Color.black.opacity(0.04)

    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    /// Neutral: a dose nobody has acted on yet.
    static let pending = adaptive(light: UIColor(white: 0.62, alpha: 1),
                                  dark: UIColor(white: 0.48, alpha: 1))
    static let taken = adaptive(light: UIColor(red: 0.13, green: 0.55, blue: 0.36, alpha: 1),
                                dark: UIColor(red: 0.40, green: 0.82, blue: 0.60, alpha: 1))
    static let skipped = adaptive(light: UIColor(red: 0.72, green: 0.45, blue: 0.12, alpha: 1),
                                  dark: UIColor(red: 0.95, green: 0.72, blue: 0.38, alpha: 1))

    /// Fill behind a neutral primary action, such as the empty state's add button.
    static let accentFill = adaptive(light: UIColor(white: 0.12, alpha: 1),
                                     dark: UIColor(white: 0.92, alpha: 1))
    static let accentLabel = adaptive(light: .white, dark: UIColor(white: 0.08, alpha: 1))

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Card

/// The single card treatment used across the app: soft surface, hairline border, barely
/// there shadow.
struct DozyCard: ViewModifier {
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Palette.card,
                in: RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous)
                    .strokeBorder(Palette.cardBorder, lineWidth: Layout.border)
            }
            .shadow(color: Palette.shadow, radius: 4, x: 0, y: 1)
    }
}

extension View {
    func dozyCard(padding: CGFloat = Spacing.lg) -> some View {
        modifier(DozyCard(padding: padding))
    }
}

// MARK: - Dose status

extension DoseStatus {
    /// The state is read from the icon and its color, never from a word.
    var iconName: String {
        switch self {
        case .pending: "circle"
        case .taken: "checkmark.circle.fill"
        case .skipped: "xmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .pending: Palette.pending
        case .taken: Palette.taken
        case .skipped: Palette.skipped
        }
    }

    /// Spoken by VoiceOver in place of the removed badge text.
    var accessibilityTitle: String {
        switch self {
        case .pending: "Bekliyor"
        case .taken: "Alındı"
        case .skipped: "Atlandı"
        }
    }
}

// MARK: - Formatting

extension Locale {
    /// The app's copy is Turkish, so dates and times are formatted to match it regardless of
    /// the device language.
    static let turkish = Locale(identifier: "tr_TR")
}

extension Color {
    /// Builds a color from `#RRGGBB` or `RRGGBB`, falling back to the accent color when the
    /// string cannot be parsed.
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
            self = .accentColor
            return
        }

        self = Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
