//
//  SpongeTheme.swift
//  Sponge
//
//  Created on 2/3/26.
//

import SwiftUI

/// Sponge app theme - coral and cream colors with clean geometric design
struct SpongeTheme {
    // MARK: - Colors

    /// Primary coral color - main brand color
    static let coral = Color(red: 255/255, green: 127/255, blue: 102/255)

    /// Light coral - for backgrounds and subtle accents
    static let coralLight = Color(red: 255/255, green: 167/255, blue: 147/255)

    /// Very light coral - for card backgrounds
    static let coralPale = Color(red: 255/255, green: 210/255, blue: 200/255)

    /// Cream color - secondary accent
    static let cream = Color(red: 252/255, green: 241/255, blue: 227/255)

/// Background coral - the main app background color
    static let backgroundCoral = Color(red: 255/255, green: 147/255, blue: 127/255)

    // MARK: - Surface Colors

    /// Main card/content background — white, provides contrast on cream
    static let surfacePrimary = Color(NSColor.windowBackgroundColor)

    /// View/sheet backgrounds — warm cream (matches onboarding)
    static let surfaceSecondary = cream

    /// Toolbar/header tints
    static let subtleBackground = Color.secondary.opacity(0.05)

    /// Badge/pill backgrounds
    static let subtleFill = Color.secondary.opacity(0.1)

    /// Card/editor borders — warm coral tint instead of cold gray
    static let subtleBorder = coral.opacity(0.15)

    /// Divider color
    static let divider = Color.gray.opacity(0.15)

    /// Icon box background — colored icon containers (matches onboarding tour)
    static func iconBoxFill(_ color: Color) -> Color {
        color.opacity(0.12)
    }

    // MARK: - Semantic Colors

    /// Primary action color (buttons, links)
    static let primary = coral

    /// Secondary action color
    static let secondary = cream

    /// Success states
    static let success = Color.green

    /// Error states
    static let error = Color.red

    /// Warning states
    static let warning = Color.orange

    // MARK: - Gradients

    /// Primary gradient - coral to light coral
    static let primaryGradient = LinearGradient(
        colors: [coral, coralLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corner Radius

    /// Extra small corner radius - for pills and small badges
    static let cornerRadiusXS: CGFloat = 6

    /// Small corner radius - for buttons and small cards
    static let cornerRadiusS: CGFloat = 8

    /// Medium corner radius - for cards
    static let cornerRadiusM: CGFloat = 12

    /// Large corner radius - for main containers
    static let cornerRadiusL: CGFloat = 20

    /// Extra large corner radius - for hero elements
    static let cornerRadiusXL: CGFloat = 28

    // MARK: - Control Sizes

    /// Small inline buttons
    static let controlSizeS: CGFloat = 28

    /// Standard action buttons
    static let controlSizeM: CGFloat = 32

    /// Primary touch targets
    static let controlSizeL: CGFloat = 44

    // MARK: - Shadows

    /// Subtle shadow for cards
    static let shadowS = Color.black.opacity(0.05)

    /// Medium shadow for elevated elements
    static let shadowM = Color.black.opacity(0.1)

    /// Strong shadow for modals and overlays
    static let shadowL = Color.black.opacity(0.2)
}

// MARK: - Color Extensions

extension Color {
    static var primaryBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }

    static var secondaryBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }

    static var tertiaryBackground: Color {
        Color(NSColor.textBackgroundColor)
    }

    static var secondarySystemBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }

    static var toastBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }
}

// MARK: - Sponge Icon Pattern View

/// A decorative view that mimics the sponge hole pattern from the app icon
struct SpongePatternView: View {
    let size: CGFloat
    let color: Color
    let spacing: CGFloat

    init(size: CGFloat = 300, color: Color = SpongeTheme.coral.opacity(0.1), spacing: CGFloat = 30) {
        self.size = size
        self.color = color
        self.spacing = spacing
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(geometry.size.width / spacing) + 1
            let rows = Int(geometry.size.height / spacing) + 1

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        let circleSize = spacing * 0.4

                        let circle = Circle()
                            .path(in: CGRect(x: x - circleSize/2, y: y - circleSize/2, width: circleSize, height: circleSize))

                        context.fill(circle, with: .color(color))
                    }
                }
            }
        }
    }
}
