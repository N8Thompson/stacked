//
//  StackedTheme.swift
//  Stacked
//
//  Brand palette and semantic tokens derived from the app icon:
//  forest green (#1D312A) and warm cream monogram (#EFE6DB).
//

import SwiftUI

// MARK: - Palette

enum StackedTheme {

    /// Fixed brand anchors — use for logos, marketing, and fixed-contrast overlays.
    enum Brand {
        /// App icon background; primary brand identity.
        static let forest = Color(hex: 0x1D312A)
        /// Monogram / wordmark on the icon.
        static let cream = Color(hex: 0xEFE6DB)
        /// Mid-tone forest for gradients and secondary surfaces.
        static let moss = Color(hex: 0x2D5247)
        /// Primary interactive accent — sage green.
        static let sage = Color(hex: 0x4A8F78)
        /// Lighter sage for gradient highlights and hover states.
        static let sageLight = Color(hex: 0x5BA88F)
        /// Deeper sage for pressed states and gradient shadows.
        static let sageDark = Color(hex: 0x3A7562)
        /// Warm antique gold for ratings and premium highlights.
        static let gold = Color(hex: 0xC4A574)
    }

    /// Screen and grouped-background fills.
    enum Background {
        static let primary = Color.adaptive(
            light: Color(hex: 0xF7F4F0),
            dark: Color(hex: 0x141F1C)
        )
        static let secondary = Color.adaptive(
            light: Color(hex: 0xEDE8E1),
            dark: Color(hex: 0x1D312A)
        )
    }

    /// Cards, sheets, and elevated containers.
    enum Surface {
        static let primary = Color.adaptive(
            light: Color(hex: 0xFAF8F5),
            dark: Color(hex: 0x1D312A)
        )
        static let elevated = Color.adaptive(
            light: .white,
            dark: Color(hex: 0x253D35)
        )
        static let muted = Color.adaptive(
            light: Color(hex: 0xF0EBE3),
            dark: Color(hex: 0x2F4A40)
        )
        /// Segmented-control and chip track backgrounds.
        static let track = Color.adaptive(
            light: Brand.forest.opacity(0.08),
            dark: Brand.cream.opacity(0.08)
        )
    }

    /// Typography hierarchy.
    enum Text {
        static let primary = Color.adaptive(
            light: Brand.forest,
            dark: Brand.cream
        )
        static let secondary = Color.adaptive(
            light: Color(hex: 0x4A5F58),
            dark: Color(hex: 0xB8AFA4)
        )
        static let tertiary = Color.adaptive(
            light: Color(hex: 0x7A8A84),
            dark: Color(hex: 0x8A8279)
        )
        /// Text on accent-colored buttons and selected chips.
        static let onAccent = Brand.cream
    }

    /// Borders, dividers, and hairlines.
    enum Border {
        static let subtle = Color.adaptive(
            light: Color(hex: 0xE0DAD2),
            dark: Color(hex: 0x2F4A40)
        )
        static let strong = Color.adaptive(
            light: Brand.forest.opacity(0.22),
            dark: Brand.cream.opacity(0.18)
        )
    }

    /// Interactive accent — tint, links, selection.
    static let accent = Brand.sage
    static let accentMuted = Brand.sage.opacity(0.18)

    enum Semantic {
        static let destructive = Color(hex: 0xC45C4A)
        static let success = Brand.sage
        static let star = Brand.gold
    }

    // MARK: - Gradients

    enum Gradient {
        /// Deep forest hero — splash headers, export covers, feature bands.
        static let forestHero = LinearGradient(
            colors: [Color(hex: 0x141F1C), Brand.forest, Brand.moss],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Primary accent — buttons, selected segments, active chips.
        static let accent = LinearGradient(
            colors: [Brand.sageDark, Brand.sage, Brand.sageLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Warm cream wash — light-mode card highlights.
        static let creamWash = LinearGradient(
            colors: [Brand.cream, Color(hex: 0xD9CFC2)],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Subtle card surface — light mode.
        static let cardLight = LinearGradient(
            colors: [Color(hex: 0xFAF8F5), Color(hex: 0xF0EBE3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Subtle card surface — dark mode.
        static let cardDark = LinearGradient(
            colors: [Color(hex: 0x1D312A), Color(hex: 0x253D35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Ambient screen wash behind content.
        static func backdrop(for scheme: ColorScheme) -> LinearGradient {
            switch scheme {
            case .dark:
                LinearGradient(
                    colors: [Brand.moss.opacity(0.35), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
            default:
                LinearGradient(
                    colors: [Brand.sage.opacity(0.10), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }

        static func card(for scheme: ColorScheme) -> LinearGradient {
            scheme == .dark ? cardDark : cardLight
        }
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        }))
        #else
        light
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - View modifiers

extension View {
    /// Full-screen branded background with a subtle top gradient wash.
    func stackedScreenBackground() -> some View {
        modifier(StackedScreenBackgroundModifier())
    }

    /// Gradient card surface with optional border — tiles, summary panels.
    func stackedCardStyle(cornerRadius: CGFloat = 14) -> some View {
        modifier(StackedCardStyleModifier(cornerRadius: cornerRadius))
    }

    /// Selected chip / pill with accent gradient.
    func stackedSelectedPill() -> some View {
        background(Capsule().fill(StackedTheme.Gradient.accent))
            .foregroundStyle(StackedTheme.Text.onAccent)
    }

    /// Unselected chip / pill track styling.
    func stackedUnselectedPill() -> some View {
        background(Capsule().fill(StackedTheme.Surface.track))
            .foregroundStyle(StackedTheme.Text.primary)
    }
}

private struct StackedScreenBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    StackedTheme.Background.primary
                    StackedTheme.Gradient.backdrop(for: colorScheme)
                }
                .ignoresSafeArea()
            }
    }
}

private struct StackedCardStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StackedTheme.Gradient.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(StackedTheme.Border.subtle, lineWidth: 1)
            )
    }
}
