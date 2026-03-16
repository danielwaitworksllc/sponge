import SwiftUI

/// Compact horizontal bar with intent marker buttons and recent marker indicators
struct IntentMarkerBar: View {
    let onMarkerTapped: (IntentMarkerType) -> Void
    let recentMarkers: [IntentMarker]

    @State private var lastTappedType: IntentMarkerType?

    var body: some View {
        HStack(spacing: SpongeTheme.spacingS) {
            // Marker buttons
            ForEach(IntentMarkerType.allCases) { type in
                MarkerButton(
                    type: type,
                    isHighlighted: lastTappedType == type,
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            lastTappedType = type
                        }
                        onMarkerTapped(type)

                        // Reset highlight after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                if lastTappedType == type {
                                    lastTappedType = nil
                                }
                            }
                        }
                    }
                )
            }

            // Divider if we have recent markers
            if !recentMarkers.isEmpty {
                Divider()
                    .frame(height: 24)
                    .padding(.horizontal, SpongeTheme.spacingXS)

                // Recent marker timestamps (last 3)
                HStack(spacing: SpongeTheme.spacingXS) {
                    ForEach(recentMarkers.suffix(3)) { marker in
                        RecentMarkerBadge(marker: marker)
                    }
                }
            }
        }
        .padding(.horizontal, SpongeTheme.spacingM)
        .padding(.vertical, SpongeTheme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                .fill(Color.primaryBackground.opacity(0.9))
                .shadow(color: SpongeTheme.shadowS, radius: 4, x: 0, y: 2)
        )
    }
}

/// Individual marker button
private struct MarkerButton: View {
    let type: IntentMarkerType
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(type.swiftUIColor)

                Text(type.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(type.swiftUIColor.opacity(0.8))
            }
            .frame(width: 50, height: 44)
            .background(
                RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                    .fill(isHighlighted ? type.swiftUIColor.opacity(0.15) : Color.clear)
            )
            .scaleEffect(isHighlighted ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

/// Small badge showing a recent marker timestamp
private struct RecentMarkerBadge: View {
    let marker: IntentMarker

    var body: some View {
        HStack(spacing: 2) {
            Text(marker.type.shortLabel)
                .font(.system(size: 10, weight: .bold))
            Text(marker.formattedTimestamp)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(marker.type.swiftUIColor.opacity(0.15))
        )
        .foregroundColor(marker.type.swiftUIColor)
    }
}

#Preview {
    VStack(spacing: 20) {
        IntentMarkerBar(
            onMarkerTapped: { type in
                print("Tapped: \(type)")
            },
            recentMarkers: []
        )

        IntentMarkerBar(
            onMarkerTapped: { type in
                print("Tapped: \(type)")
            },
            recentMarkers: [
                IntentMarker(type: .confused, timestamp: 135),
                IntentMarker(type: .important, timestamp: 272),
                IntentMarker(type: .examRelevant, timestamp: 421)
            ]
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
