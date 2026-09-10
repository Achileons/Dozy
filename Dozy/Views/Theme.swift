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

    /// Generous radii are most of what makes the surfaces feel soft; every corner is
    /// continuous so the curve never shows a seam where it meets the edge.
    static let cardCorner: CGFloat = 24
    static let controlCorner: CGFloat = 16
    static let border: CGFloat = 1
    /// A ring that has to read as a choice rather than as an edge.
    static let selectedBorder: CGFloat = 2.5

    static let cardShadowRadius: CGFloat = 12
    static let cardShadowOffset: CGFloat = 4

    /// The band down the leading edge of a card, wide enough to read as a status at a
    /// glance without crowding the text beside it.
    static let cardStripe: CGFloat = 5

    /// The sheet-like plane the selected day's doses sit on, raised off the calendar above
    /// it. Rounded more than a card, the way a sheet is.
    static let layerCorner: CGFloat = 28
    static let layerShadowRadius: CGFloat = 16
    /// Negative: the layer's shadow falls upwards, onto what it covers.
    static let layerShadowOffset: CGFloat = -4
    static let grabberWidth: CGFloat = 36
    static let grabberHeight: CGFloat = 5

    static let statusIcon: CGFloat = 28
    /// Large enough that the colour is a mark, not a speck.
    static let medicationDot: CGFloat = 14
    static let colorSwatch: CGFloat = 44
    static let actionButton: CGFloat = 52

    /// A calendar day is a disc; this is its diameter. Sized so seven fit across a phone
    /// with room between them.
    static let dayCell: CGFloat = 44
    /// The mark under today's number.
    static let todayDot: CGFloat = 5

    static let progressRing: CGFloat = 104
    /// Thick enough to have presence, thin enough to stay a line rather than a band.
    static let progressStroke: CGFloat = 9

    /// The pill glyph showing how full a package is.
    static let stockIcon: CGFloat = 22
    /// The colour keys in the month tally under the calendar.
    static let summaryDot: CGFloat = 8

    /// How far a screen title may shrink before wrapping, for a greeting that has to share
    /// its line with nothing but still fit the longest wording.
    static let titleScale: CGFloat = 0.8

    static let emptyIcon: CGFloat = 56
    /// Icons that sit inline beside text, like the scan button.
    static let inlineIcon: CGFloat = 22
}

// MARK: - Opacity

/// The few translucencies in use, named for what they do rather than what they are.
enum Opacity {
    /// Content of a dose that has been dealt with; it steps back without disappearing.
    static let settled = 0.55
    /// A caption laid over the camera.
    static let scrim = 0.85
    /// A border that suggests rather than states.
    static let softBorder = 0.4
    /// The part of the stock glyph that has been used up: still visible as an outline of
    /// what the package would hold when full.
    static let emptyStock = 0.22
}

// MARK: - Motion

/// The two speeds the app moves at, plus the one transition that is not a plain fade.
enum Motion {
    /// State changes the user caused: a dose ticked, a day picked. Bounces a little, so the
    /// tap is felt as well as seen.
    static let spring = Animation.spring(duration: 0.45, bounce: 0.28)
    /// Changes of context, like moving between months: settled rather than playful.
    static let gentle = Animation.easeInOut(duration: 0.3)

    /// A month leaving or arriving: it breathes in rather than slides, which keeps the
    /// grid feeling like one object that changed rather than two that swapped.
    static let monthTransition: AnyTransition = .opacity.combined(with: .scale(scale: 0.97))
}

// MARK: - Typography

// MARK: - Colors

/// Warm throughout: the neutrals lean cream in the light and brown in the dark, so even the
/// empty page has a temperature. Colour beyond that carries meaning — the signature coral
/// for anything the user chose or should look at, and three pastels for how a dose went.
/// Each value is a pair, one for each appearance, so dark mode is designed rather than
/// derived.
enum Palette {

    // MARK: Surfaces

    /// The page. Not white: a cream just off it, which is what keeps the app from looking
    /// like a form.
    static let surface = dynamic(light: "#FDF8F5", dark: "#1C1917")
    /// Cards sit a touch above the page, close enough to belong to it.
    static let card = dynamic(light: "#FFFDFB", dark: "#26211E")
    static let cardBorder = dynamic(light: "#EFE2DA", dark: "#37312D")
    static let shadow = Color.black.opacity(0.08)

    /// The plane the selected day's doses ride on: a step warmer than the page, so the
    /// two read as separate layers rather than one flat field.
    static let layer = dynamic(light: "#FFFFFF", dark: "#241F1C")
    static let layerShadow = Color.black.opacity(0.10)
    /// The handle at the top of that plane.
    static let grabber = dynamic(light: "#E4D6CE", dark: "#433B36")

    // MARK: Text

    static let primaryText = Color(uiColor: primaryTextColor)
    static let secondaryText = dynamic(light: "#8C7F78", dark: "#A89C94")

    /// UIKit needs this one for the navigation bar, which SwiftUI does not style.
    static let primaryTextColor = dynamicColor(light: "#2E2724", dark: "#F4EEE9")

    // MARK: Signature

    /// Coral, warmed towards peach. A little lighter at night so it glows on the dark
    /// ground instead of sinking into it.
    static let accent = dynamic(light: "#FF6B4A", dark: "#FF8663")
    /// A wash of the signature, for a track behind a ring or a chip that is selected but
    /// should not shout.
    static let accentSoft = dynamic(light: "#FFDDD3", dark: "#4A2E26")
    static let accentLabel = Color.white

    /// The fill behind a primary action. The same coral; named for its job.
    static let accentFill = accent

    // MARK: Dose state

    /// A dose nobody has acted on yet: a warm neutral, present but quiet.
    static let pending = dynamic(light: "#B0A29A", dark: "#7B6F68")
    /// Sage rather than green: taken is calm, not triumphant.
    static let taken = dynamic(light: "#4F9E70", dark: "#6FC793")
    /// Terracotta rather than red: missed is a nudge, not an alarm. Also the tint of
    /// anything destructive.
    static let missed = dynamic(light: "#D2543A", dark: "#EE7E60")
    /// Amber, for a day that is half done.
    static let partial = dynamic(light: "#E3A020", dark: "#F2B94A")

    /// Washes of the three tones above, used to fill a whole calendar day. Strong enough
    /// to be read across the grid at arm's length — a month's shape should be legible
    /// without looking at any one day — while still sitting behind the number rather than
    /// competing with it.
    static let takenFill = dynamic(light: "#C6E6D3", dark: "#2F5843")
    static let partialFill = dynamic(light: "#FAE2B4", dark: "#574320")
    static let missedFill = dynamic(light: "#F9CEC2", dark: "#70402F")

    /// The unfilled part of the progress ring.
    static let ringTrack = dynamic(light: "#F2E2DB", dark: "#3A322D")

    // MARK: Helpers

    private static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: dynamicColor(light: light, dark: dark))
    }

    private static func dynamicColor(light: String, dark: String) -> UIColor {
        let lightColor = UIColor(hex: light)
        let darkColor = UIColor(hex: dark)
        return UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor }
    }
}

// MARK: - Appearance

/// The one place SwiftUI cannot reach: the navigation bar's title fonts come from UIKit, so
/// they are set here once at launch, in the same faces the rest of the app uses.
enum Appearance {
    static func apply() {
        FontRegistry.reportMissingFaces()

        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [
            .font: UIFont.dozy(.largeTitle),
            .foregroundColor: Palette.primaryTextColor
        ]
        navigationBar.titleTextAttributes = [
            .font: UIFont.dozy(.titleCompact),
            .foregroundColor: Palette.primaryTextColor
        ]
    }
}

// MARK: - Card

/// The single card treatment used across the app: soft surface, hairline border, a shadow
/// felt more than seen.
struct DozyCard: ViewModifier {
    var padding: CGFloat = Spacing.lg
    /// A band down the leading edge, for a card that has a status to report.
    var stripe: Color?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The stripe is clipped by the card's own shape, so it follows the corner
            // curve instead of cutting across it. Only the fill is clipped — the border
            // and shadow are applied after, and would be swallowed by the clip.
            .background {
                shape
                    .fill(Palette.card)
                    .overlay(alignment: .leading) {
                        if let stripe {
                            Rectangle()
                                .fill(stripe)
                                .frame(width: Layout.cardStripe)
                        }
                    }
                    .clipShape(shape)
            }
            .overlay {
                shape.strokeBorder(Palette.cardBorder, lineWidth: Layout.border)
            }
            .shadow(
                color: Palette.shadow,
                radius: Layout.cardShadowRadius,
                x: 0,
                y: Layout.cardShadowOffset
            )
    }
}

extension View {
    func dozyCard(padding: CGFloat = Spacing.lg, stripe: Color? = nil) -> some View {
        modifier(DozyCard(padding: padding, stripe: stripe))
    }
}

// MARK: - Dose status

extension DoseStatus {
    /// The state is read from the icon and its color, never from a word.
    var iconName: String {
        switch self {
        case .pending: "circle"
        case .taken: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending: Palette.pending
        case .taken: Palette.taken
        }
    }

    /// Spoken by VoiceOver in place of the removed badge text.
    var accessibilityTitle: String {
        switch self {
        case .pending: "Bekliyor"
        case .taken: "Alındı"
        }
    }
}

// MARK: - Stock

extension Medication {
    /// The colour that speaks for the package. While there is enough left it is simply the
    /// medication's own colour, so the list reads as a set of medications rather than a set
    /// of warnings; it turns amber and then terracotta only when there is something to say.
    var stockTint: Color {
        guard stockEnabled else { return Color(hex: colorHex) }

        if currentStock <= 0 { return Palette.missed }
        if currentStock <= lowStockThreshold { return Palette.partial }
        return Color(hex: colorHex)
    }

    /// The tint for the stock *line* under the name. The same warnings as `stockTint`, but
    /// it falls back to plain secondary text rather than to the medication's own colour,
    /// which is chosen for a dot on a surface and need not be readable as text.
    var stockTextTint: Color {
        guard stockEnabled else { return Palette.secondaryText }

        if currentStock <= 0 { return Palette.missed }
        if currentStock <= lowStockThreshold { return Palette.partial }
        return Palette.secondaryText
    }

    /// How full the package is, from empty to full. A medication tracking stock without a
    /// package size has nothing to be a fraction of, so it reads as full while any is left.
    var stockFraction: Double {
        guard currentStock > 0 else { return 0 }
        guard packageSize > 0 else { return 1 }
        return min(1, Double(currentStock) / Double(packageSize))
    }
}

// MARK: - Formatting

extension Locale {
    /// The app's copy is Turkish, so dates and times are formatted to match it regardless of
    /// the device language.
    static let turkish = Locale(identifier: "tr_TR")
}

extension UIColor {
    /// Builds a colour from `#RRGGBB` or `RRGGBB`. Falls back to the label colour when the
    /// string cannot be parsed, which keeps a typo visible rather than invisible.
    convenience init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
            self.init(cgColor: UIColor.label.cgColor)
            return
        }

        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
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
