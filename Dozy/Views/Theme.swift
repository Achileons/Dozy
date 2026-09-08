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

    static let cardShadowRadius: CGFloat = 8
    static let cardShadowOffset: CGFloat = 2

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

    static let progressRing: CGFloat = 96
    /// Thick enough to have presence, thin enough to stay a line rather than a band.
    static let progressStroke: CGFloat = 9

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

/// Named text styles, so no view reaches for a font of its own. Rounded where a word is
/// meant to feel friendly — titles, names, numbers the user reads at a glance — and plain
/// where a line is meant to be read through.
enum Typography {
    static let screenTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let sectionTitle = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let itemTitle = Font.system(.headline, design: .rounded)
    static let itemDetail = Font.subheadline
    static let time = Font.system(.title3, design: .rounded).weight(.semibold)
    static let meta = Font.footnote
    static let control = Font.system(.subheadline, design: .rounded).weight(.semibold)

    static let dayNumber = Font.system(.body, design: .rounded)
    static let weekday = Font.system(.footnote, design: .rounded).weight(.medium)
    static let ringValue = Font.system(.title2, design: .rounded).weight(.bold)
    static let emptyTitle = Font.system(.title3, design: .rounded).weight(.semibold)
    static let inlineIcon = Font.system(size: Layout.inlineIcon, weight: .medium)
}

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
    static let cardBorder = dynamic(light: "#F0E6E0", dark: "#35302C")
    static let shadow = Color.black.opacity(0.04)

    // MARK: Text

    static let primaryText = Color(uiColor: primaryTextColor)
    static let secondaryText = dynamic(light: "#8C7F78", dark: "#A89C94")

    /// UIKit needs this one for the navigation bar, which SwiftUI does not style.
    static let primaryTextColor = dynamicColor(light: "#2E2724", dark: "#F4EEE9")

    // MARK: Signature

    /// Coral, warmed towards peach. A little lighter at night so it glows on the dark
    /// ground instead of sinking into it.
    static let accent = dynamic(light: "#FF8A70", dark: "#FF9A80")
    /// A wash of the signature, for a track behind a ring or a chip that is selected but
    /// should not shout.
    static let accentSoft = dynamic(light: "#FFE6DE", dark: "#3E2A24")
    static let accentLabel = Color.white

    /// The fill behind a primary action. The same coral; named for its job.
    static let accentFill = accent

    // MARK: Dose state

    /// A dose nobody has acted on yet: a warm neutral, present but quiet.
    static let pending = dynamic(light: "#C4B8B1", dark: "#6E635D")
    /// Sage rather than green: taken is calm, not triumphant.
    static let taken = dynamic(light: "#7DA98C", dark: "#93C0A2")
    /// Terracotta rather than red: missed is a nudge, not an alarm. Also the tint of
    /// anything destructive.
    static let missed = dynamic(light: "#C9705A", dark: "#E08A72")
    /// Amber, for a day that is half done.
    static let partial = dynamic(light: "#D9A441", dark: "#E8BB66")

    /// Washes of the three tones above, used to fill a whole calendar day. Barely there:
    /// the day number stays the loudest thing in the disc, and the colour is read as a
    /// tint of the page rather than a badge on it.
    static let takenFill = dynamic(light: "#E6F0E8", dark: "#23302A")
    static let partialFill = dynamic(light: "#F8EBD3", dark: "#3A3020")
    static let missedFill = dynamic(light: "#F6E1DB", dark: "#3A2823")

    /// The unfilled part of the progress ring.
    static let ringTrack = dynamic(light: "#F3E9E4", dark: "#332C28")

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
/// they are set here once at launch, in the same rounded face the rest of the app uses.
enum Appearance {
    static func apply() {
        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [
            .font: rounded(.largeTitle, weight: .bold),
            .foregroundColor: Palette.primaryTextColor
        ]
        navigationBar.titleTextAttributes = [
            .font: rounded(.headline, weight: .semibold),
            .foregroundColor: Palette.primaryTextColor
        ]
    }

    /// The system size for `style`, in the rounded design.
    private static func rounded(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Card

/// The single card treatment used across the app: soft surface, hairline border, a shadow
/// felt more than seen.
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
            .shadow(
                color: Palette.shadow,
                radius: Layout.cardShadowRadius,
                x: 0,
                y: Layout.cardShadowOffset
            )
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
