//
//  DesignSystemComponents.swift
//  Sponge
//
//  Created by Claude on 2026-02-03.
//

import SwiftUI

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: SpongeTheme.controlSizeL)
            .background(isDestructive ? Color.red : color)
            .cornerRadius(SpongeTheme.cornerRadiusM)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
