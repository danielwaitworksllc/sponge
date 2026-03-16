import SwiftUI

/// Tab-based view showing available summaries from a recording
struct EnhancedSummaryView: View {
    @Bindable var recording: SDRecording

    @State private var selectedTab: SummaryTab = .overview

    enum SummaryTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case clarifications = "Clarifications"
        case examPrep = "Exam Prep"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .overview:
                return "doc.text"
            case .clarifications:
                return "questionmark.circle"
            case .examPrep:
                return "star.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: SpongeTheme.spacingM) {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .clarifications:
                        clarificationsContent
                    case .examPrep:
                        examPrepContent
                    }
                }
                .padding(SpongeTheme.spacingM)
            }
        }
        .onAppear {
            // Auto-select first available tab
            if !hasOverview && hasClarifications {
                selectedTab = .clarifications
            } else if !hasOverview && hasExamPrep {
                selectedTab = .examPrep
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: SpongeTheme.spacingS) {
            ForEach(availableTabs) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    markerCount: markerCount(for: tab),
                    onTap: { selectedTab = tab }
                )
            }
        }
        .padding(.horizontal, SpongeTheme.spacingM)
        .padding(.vertical, SpongeTheme.spacingS)
    }

    private var availableTabs: [SummaryTab] {
        var tabs: [SummaryTab] = []
        if hasOverview { tabs.append(.overview) }
        if hasClarifications { tabs.append(.clarifications) }
        if hasExamPrep { tabs.append(.examPrep) }
        return tabs.isEmpty ? [.overview] : tabs // Always show at least overview
    }

    // MARK: - Content Views

    @ViewBuilder
    private var overviewContent: some View {
        if let overview = recording.enhancedSummary?.generalOverview {
            SummaryCard(
                title: "General Overview",
                icon: "doc.text",
                content: overview
            )
        } else if let classNotes = recording.classNotes {
            SummaryCard(
                title: "Class Notes",
                icon: "doc.text",
                content: classNotes
            )
        } else {
            SummaryEmptyStateView(
                icon: "doc.text",
                title: "No Summary Available",
                message: "Enable class notes generation in settings to get summaries."
            )
        }
    }

    @ViewBuilder
    private var clarificationsContent: some View {
        if let clarifications = recording.enhancedSummary?.confusionFocused {
            VStack(alignment: .leading, spacing: SpongeTheme.spacingM) {
                // Marker summary
                if confusedMarkerCount > 0 {
                    MarkerSummaryBadge(
                        count: confusedMarkerCount,
                        type: .confused
                    )
                }

                SummaryCard(
                    title: "Clarifications",
                    icon: "questionmark.circle",
                    content: clarifications
                )
            }
        } else {
            SummaryEmptyStateView(
                icon: "questionmark.circle",
                title: "No Clarifications",
                message: "Mark moments as 'Confused' during recording to get targeted clarifications."
            )
        }
    }

    @ViewBuilder
    private var examPrepContent: some View {
        if let examPrep = recording.enhancedSummary?.examOriented {
            VStack(alignment: .leading, spacing: SpongeTheme.spacingM) {
                // Marker summary
                let examCount = examMarkerCount
                if examCount > 0 {
                    HStack(spacing: SpongeTheme.spacingS) {
                        if importantMarkerCount > 0 {
                            MarkerSummaryBadge(count: importantMarkerCount, type: .important)
                        }
                        if examRelevantMarkerCount > 0 {
                            MarkerSummaryBadge(count: examRelevantMarkerCount, type: .examRelevant)
                        }
                    }
                }

                SummaryCard(
                    title: "Exam Preparation",
                    icon: "star.fill",
                    content: examPrep
                )
            }
        } else {
            SummaryEmptyStateView(
                icon: "star.fill",
                title: "No Exam Notes",
                message: "Mark moments as 'Important' or 'Exam' during recording to get exam-focused summaries."
            )
        }
    }

    // MARK: - Computed Properties

    private var hasOverview: Bool {
        recording.enhancedSummary?.generalOverview != nil || recording.classNotes != nil
    }

    private var hasClarifications: Bool {
        recording.enhancedSummary?.confusionFocused != nil
    }

    private var hasExamPrep: Bool {
        recording.enhancedSummary?.examOriented != nil
    }

    private var confusedMarkerCount: Int {
        recording.intentMarkers.filter { $0.type == .confused }.count
    }

    private var importantMarkerCount: Int {
        recording.intentMarkers.filter { $0.type == .important }.count
    }

    private var examRelevantMarkerCount: Int {
        recording.intentMarkers.filter { $0.type == .examRelevant }.count
    }

    private var examMarkerCount: Int {
        importantMarkerCount + examRelevantMarkerCount
    }

    private func markerCount(for tab: SummaryTab) -> Int? {
        switch tab {
        case .overview:
            return nil
        case .clarifications:
            let count = confusedMarkerCount
            return count > 0 ? count : nil
        case .examPrep:
            let count = examMarkerCount
            return count > 0 ? count : nil
        }
    }
}

// MARK: - Supporting Views

private struct TabButton: View {
    let tab: EnhancedSummaryView.SummaryTab
    let isSelected: Bool
    let markerCount: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .medium))

                if let count = markerCount {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SpongeTheme.coral))
                }
            }
            .foregroundColor(isSelected ? SpongeTheme.coral : .secondary)
            .padding(.horizontal, SpongeTheme.spacingM)
            .padding(.vertical, SpongeTheme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                    .fill(isSelected ? SpongeTheme.coral.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SummaryCard: View {
    let title: String
    let icon: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(SpongeTheme.coral)
                Text(title)
                    .font(.headline)
            }

            Text(content)
                .font(.body)
                .lineSpacing(4)
        }
        .padding(SpongeTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                .fill(SpongeTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                .stroke(SpongeTheme.subtleBorder, lineWidth: 1)
        )
    }
}

private struct MarkerSummaryBadge: View {
    let count: Int
    let type: IntentMarkerType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 12))
            Text("\(count) \(type.displayName.lowercased()) marker\(count == 1 ? "" : "s")")
                .font(.caption)
        }
        .foregroundColor(type.swiftUIColor)
        .padding(.horizontal, SpongeTheme.spacingS)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(type.swiftUIColor.opacity(0.1))
        )
    }
}

private struct SummaryEmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: SpongeTheme.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpongeTheme.spacingXL)
    }
}

#Preview {
    EnhancedSummaryView(
        recording: SDRecording(
            classId: UUID(),
            audioFileName: "test.m4a",
            intentMarkers: [
                IntentMarker(type: .confused, timestamp: 120),
                IntentMarker(type: .examRelevant, timestamp: 240),
                IntentMarker(type: .important, timestamp: 360)
            ],
            enhancedSummary: EnhancedSummary(
                generalOverview: "This lecture covered the fundamentals of data structures...",
                confusionFocused: "The red-black tree balancing was confusing. Here's a clearer explanation...",
                examOriented: "Key exam topics include: 1) Big O notation, 2) Tree traversals..."
            )
        )
    )
}
