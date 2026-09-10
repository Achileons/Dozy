//
//  Typography.swift
//  Dozy
//

import SwiftUI
import UIKit

// MARK: - Faces

/// The two faces the app is set in, identified by PostScript name — which is what
/// `Font.custom` looks up, and which is not the file name (`Quicksand-Bold.ttf` holds a font
/// named `Quicksand-Bold`, but that correspondence is a convention, not a rule).
///
/// Quicksand names things: geometric and round, it carries the words that label a screen.
/// Nunito is read rather than looked at: humanist and open, it carries everything else.
enum FontFace: String, CaseIterable {
    case headingSemiBold = "Quicksand-SemiBold"
    case headingBold = "Quicksand-Bold"

    case bodyRegular = "Nunito-Regular"
    case bodySemiBold = "Nunito-SemiBold"
    case bodyBold = "Nunito-Bold"

    /// The file that has to be in `Resources/Fonts` and listed under `UIAppFonts`.
    var fileName: String { "\(rawValue).ttf" }

    /// What the system face has to do when this one is missing. Quicksand is geometric and
    /// round, so `.rounded` stands in for it; Nunito is a plain humanist sans, and the
    /// default system face is the nearest thing to it.
    var fallbackDesign: Font.Design {
        switch self {
        case .headingSemiBold, .headingBold: .rounded
        case .bodyRegular, .bodySemiBold, .bodyBold: .default
        }
    }

    var fallbackWeight: Font.Weight {
        switch self {
        case .headingSemiBold: .semibold
        case .headingBold: .bold
        case .bodyRegular: .regular
        case .bodySemiBold: .semibold
        case .bodyBold: .bold
        }
    }

    var isInstalled: Bool { FontRegistry.isInstalled(self) }
}

// MARK: - Registry

/// Whether the font files actually made it into the bundle.
///
/// A missing font is not a crash and not a blank screen — `Font.custom` quietly falls back
/// to the system face on its own — but it is also not visible, which is how a project ends
/// up shipping with half its type silently wrong. Every style here asks this first and
/// chooses a deliberate fallback, and `#if DEBUG` says so in the console once at launch.
enum FontRegistry {

    /// Read once. `UIAppFonts` registers before any app code runs, so the set cannot change
    /// underneath us afterwards.
    private static let installedNames: Set<String> = {
        Set(UIFont.familyNames.flatMap(UIFont.fontNames(forFamilyName:)))
    }()

    static func isInstalled(_ face: FontFace) -> Bool {
        installedNames.contains(face.rawValue)
    }

    static var missingFaces: [FontFace] {
        FontFace.allCases.filter { !$0.isInstalled }
    }

    /// Called at launch. Says nothing at all when every face is present.
    static func reportMissingFaces() {
        #if DEBUG
        let missing = missingFaces
        guard !missing.isEmpty else { return }

        print("""
        [Dozy] \(missing.count) of \(FontFace.allCases.count) custom fonts are not installed; \
        the system face is standing in for them.
          missing: \(missing.map(\.fileName).joined(separator: ", "))
          fix: put the files in Dozy/Resources/Fonts and check they are listed in Dozy/Info.plist
        """)
        #endif
    }
}

// MARK: - Roles

/// Every text style in the app, and the only place a font size is written down.
///
/// The sizes are the ones the app already had, so switching faces moves no layout: each
/// matches the default size of the text style it scales against, which puts the scale
/// factor at exactly 1 for a reader who has not changed their text size.
enum TextRole: CaseIterable {

    // MARK: Naming — Quicksand

    /// A screen's own name: the greeting on Bugün.
    case largeTitle
    /// The month above the calendar.
    case title
    /// A day, or the heading of an empty screen.
    case title2
    /// A screen name in a collapsed navigation bar, where there is only a line's height to
    /// work with.
    case titleCompact

    // MARK: Working — Nunito

    /// The name of a row: a medication, a dose.
    case headline
    /// Section headings and the labels on controls.
    case callout
    /// Detail under a title, and any sentence meant to be read through.
    case body
    /// Captions, metadata, the smallest thing on screen.
    case caption
    /// A caption that has to hold its own as a label, like the weekday row.
    case captionStrong

    // MARK: Figures — Nunito, tabular

    /// Times in a dose row.
    case numeric
    /// The count inside the progress ring.
    case numericLarge
    /// Day numbers in the calendar grid.
    case numericSmall
    /// Today's number among them. A separate role rather than `.fontWeight(.bold)`, which
    /// cannot pick another file out of a custom family the way it can a system weight.
    case numericSmallStrong

    var face: FontFace {
        switch self {
        case .largeTitle, .title: .headingBold
        case .title2, .titleCompact: .headingSemiBold
        case .headline, .numericLarge, .numericSmallStrong: .bodyBold
        case .callout, .captionStrong, .numeric: .bodySemiBold
        case .body, .caption, .numericSmall: .bodyRegular
        }
    }

    var size: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2, .numericLarge: 22
        case .headline, .numeric: 20
        case .titleCompact, .numericSmall, .numericSmallStrong: 17
        case .callout: 15
        case .body: 13
        case .caption, .captionStrong: 12
        }
    }

    /// The system style this scales against under Dynamic Type. Paired with a matching
    /// `size`, so the starting point is the size above and everything grows from there.
    var textStyle: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2, .numericLarge: .title2
        case .headline, .numeric: .title3
        case .titleCompact: .headline
        case .numericSmall, .numericSmallStrong: .body
        case .callout: .subheadline
        case .body: .footnote
        case .caption, .captionStrong: .caption
        }
    }

    /// Quicksand sets wide — it is a geometric face with round, open counters — so at
    /// display sizes a title reads as spaced-out lettering unless it is pulled in slightly.
    /// The larger the size, the more it needs. Nunito needs none of this at text sizes.
    var tracking: CGFloat {
        switch self {
        case .largeTitle: -0.6
        case .title: -0.5
        case .title2: -0.3
        case .titleCompact: -0.2
        default: 0
        }
    }

    /// Nunito has a tall x-height, which closes up the gap between lines of wrapped text.
    /// Only styles that actually wrap get any back.
    var lineSpacing: CGFloat {
        switch self {
        case .body: 1
        default: 0
        }
    }

    /// Digits that do not change width as they change value, so a time or a count does not
    /// jitter when it updates. A no-op on a face without tabular figures.
    var usesTabularFigures: Bool {
        switch self {
        case .numeric, .numericLarge, .numericSmall, .numericSmallStrong: true
        default: false
        }
    }
}

// MARK: - Fonts

extension Font {

    /// The app's type scale. Namespaced rather than added as `Font.headline` and friends,
    /// which already exist on `Font` and would make every call site ambiguous.
    static func dozy(_ role: TextRole) -> Font {
        let base: Font = role.face.isInstalled
            ? .custom(role.face.rawValue, size: role.size, relativeTo: role.textStyle)
            : .system(role.textStyle, design: role.face.fallbackDesign)
                .weight(role.face.fallbackWeight)

        return role.usesTabularFigures ? base.monospacedDigit() : base
    }

    /// An SF Symbol sized to sit on a line of text. Symbols are drawn from the system face
    /// whatever the words around them are set in, so this deliberately does not go looking
    /// for Quicksand or Nunito.
    static func dozyIcon(_ role: TextRole, weight: Font.Weight = .medium) -> Font {
        .system(size: role.size, weight: weight)
    }

    /// An SF Symbol at a size the layout dictates rather than the text scale.
    static func dozyIcon(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
}

extension UIFont {

    /// The UIKit half, for the navigation bar — the one piece of text SwiftUI cannot style.
    /// Scaled through `UIFontMetrics` so it answers to Dynamic Type the same way the
    /// SwiftUI side does.
    static func dozy(_ role: TextRole) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: UIFont.TextStyle(role.textStyle))

        if role.face.isInstalled, let font = UIFont(name: role.face.rawValue, size: role.size) {
            return metrics.scaledFont(for: font)
        }

        let fallback = UIFont.systemFont(ofSize: role.size, weight: UIFont.Weight(role.face.fallbackWeight))
        guard let descriptor = fallback.fontDescriptor.withDesign(UIFontDescriptor.SystemDesign(role.face.fallbackDesign)) else {
            return metrics.scaledFont(for: fallback)
        }
        return metrics.scaledFont(for: UIFont(descriptor: descriptor, size: role.size))
    }
}

// MARK: - Text styles

extension View {

    /// Applies a role's face together with the tracking and line spacing its metrics need.
    ///
    /// Preferred over `.font(.dozy(_:))` for text, because it carries the whole style rather
    /// than half of it: a heading set without its tracking is not the style, just its size.
    func textStyle(_ role: TextRole) -> some View {
        font(.dozy(role))
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
    }
}

// MARK: - UIKit bridging

private extension UIFont.TextStyle {
    init(_ style: Font.TextStyle) {
        switch style {
        case .largeTitle: self = .largeTitle
        case .title: self = .title1
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .subheadline: self = .subheadline
        case .body: self = .body
        case .callout: self = .callout
        case .footnote: self = .footnote
        case .caption: self = .caption1
        case .caption2: self = .caption2
        @unknown default: self = .body
        }
    }
}

private extension UIFont.Weight {
    init(_ weight: Font.Weight) {
        switch weight {
        case .bold: self = .bold
        case .semibold: self = .semibold
        case .medium: self = .medium
        default: self = .regular
        }
    }
}

private extension UIFontDescriptor.SystemDesign {
    init(_ design: Font.Design) {
        switch design {
        case .rounded: self = .rounded
        case .serif: self = .serif
        case .monospaced: self = .monospaced
        default: self = .default
        }
    }
}
