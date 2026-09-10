//
//  StockIndicator.swift
//  Dozy
//

import SwiftUI

/// How full a package is, drawn as a pill that empties from the top down.
///
/// SF Symbols has no glyph that fills by a fraction, so this stacks two copies of the same
/// one: a faint whole pill for what the package holds, and a solid copy masked to the part
/// still left. Both come from the same symbol at the same size, so they land exactly on top
/// of one another whatever the glyph does at a given weight.
struct StockIndicator: View {
    /// From empty to full.
    let fraction: Double
    let tint: Color

    private var clamped: Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        pill
            .foregroundStyle(tint.opacity(Opacity.emptyStock))
            .overlay {
                pill
                    .foregroundStyle(tint)
                    .mask(alignment: .bottom) {
                        // Measured rather than fixed, so the mask tracks whatever height
                        // the glyph takes at the reader's text size.
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(height: proxy.size.height * clamped)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
            }
            .animation(Motion.spring, value: clamped)
            .accessibilityHidden(true)
    }

    private var pill: some View {
        Image(systemName: "pills.fill")
            .font(.dozyIcon(size: Layout.stockIcon))
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        StockIndicator(fraction: 1, tint: Palette.taken)
        StockIndicator(fraction: 0.6, tint: Color(hex: "#4A90E2"))
        StockIndicator(fraction: 0.25, tint: Palette.partial)
        StockIndicator(fraction: 0, tint: Palette.missed)
    }
    .padding(Spacing.xl)
    .background(Palette.surface)
}
