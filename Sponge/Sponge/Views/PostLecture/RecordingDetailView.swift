import SwiftUI

/// Detail view for a recording with segmented navigation
struct RecordingDetailView: View {
    @Bindable var recording: SDRecording
    let className: String

    @State private var selectedTab: DetailTab = .transcript
    @EnvironmentObject private var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss

    enum DetailTab: String, CaseIterable, Identifiable {
        case transcript = "Transcript"
        case summaries = "Summaries"
        case recall = "Recall"
        case markers = "Markers"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .transcript:
                return "doc.text"
            case .summaries:
                return "doc.richtext"
            case .recall:
                return "brain.head.profile"
            case .markers:
                return "flag.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Segmented control
            segmentedControl

            Divider()

            // Content
            tabContent
        }
        .background(SpongeTheme.coralPale.opacity(0.4))
        .frame(minWidth: 600, minHeight: 500)
        .alert("Regeneration Failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.headline)

                HStack(spacing: SpongeTheme.spacingS) {
                    Label(recording.formattedDuration, systemImage: "clock")
                    Label(recording.formattedDate, systemImage: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.isGeneratingNotes || viewModel.isImprovingTranscript {
                HStack(spacing: SpongeTheme.spacingS) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(viewModel.isImprovingTranscript ? "Improving transcript..." : "Regenerating...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: SpongeTheme.spacingS) {
                    Button {
                        Task { await viewModel.retranscribeWithWhisper(for: recording) }
                    } label: {
                        Label("Whisper", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .disabled(recording.audioFileURL() == nil)
                    .help("Re-transcribe audio on-device using Whisper for higher accuracy")

                    Button {
                        Task { await viewModel.improveTranscriptWithGemini(for: recording) }
                    } label: {
                        Label("Improve Transcript", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .disabled(recording.audioFileURL() == nil)
                    .help("Upload audio to Gemini AI for a higher-quality transcript with punctuation and speaker labels (~$0.07/hr)")

                    Button {
                        Task { await viewModel.regenerateAIContent(for: recording) }
                    } label: {
                        Label("Regenerate Notes", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(recording.transcriptText.isEmpty)
                    .help(recording.transcriptText.isEmpty ? "No transcript available" : "Regenerate AI notes, summaries, and recall prompts")
                }
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(SpongeTheme.coral)
        }
        .padding(SpongeTheme.spacingM)
        .background(SpongeTheme.cream)
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: SpongeTheme.spacingS) {
            ForEach(DetailTab.allCases) { tab in
                TabSegmentButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badgeCount: badgeCount(for: tab),
                    onTap: { selectedTab = tab }
                )
            }
        }
        .padding(.horizontal, SpongeTheme.spacingM)
        .padding(.vertical, SpongeTheme.spacingS)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .transcript:
            transcriptView
        case .summaries:
            EnhancedSummaryView(recording: recording)
        case .recall:
            RecallPromptsView(recording: recording)
        case .markers:
            markersView
        }
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpongeTheme.spacingM) {
                // Transcript
                if !recording.transcriptText.isEmpty {
                    VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(SpongeTheme.coral)
                            Text("Transcript")
                                .font(.headline)
                            Spacer()
                            Text("\(recording.transcriptText.split(separator: " ").count) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(recording.transcriptText)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding(SpongeTheme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                            .fill(SpongeTheme.cream)
                            .shadow(color: SpongeTheme.shadowS, radius: 4, x: 0, y: 2)
                    )
                } else {
                    emptyState(
                        icon: "waveform",
                        title: "No Transcript",
                        message: "This recording doesn't have a transcript."
                    )
                }

                // User Notes
                if !recording.userNotes.isEmpty {
                    VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(SpongeTheme.coral)
                            Text("Your Notes")
                                .font(.headline)
                        }

                        Text(recording.userNotes)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding(SpongeTheme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                            .fill(SpongeTheme.cream)
                            .shadow(color: SpongeTheme.shadowS, radius: 4, x: 0, y: 2)
                    )
                }
            }
            .padding(SpongeTheme.spacingM)
        }
    }

    // MARK: - Markers View

    @State private var selectedMarker: IntentMarker?

    private var markersView: some View {
        Group {
            if recording.intentMarkers.isEmpty {
                emptyState(
                    icon: "flag",
                    title: "No Markers",
                    message: "You didn't mark any moments during this recording."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
                        // Summary header
                        markersSummary

                        Divider()
                            .padding(.vertical, SpongeTheme.spacingS)

                        // Timeline of markers
                        ForEach(recording.intentMarkers.sorted { $0.timestamp < $1.timestamp }) { marker in
                            MarkerTimelineRow(marker: marker, onTap: {
                                selectedMarker = marker
                            })
                        }
                    }
                    .padding(SpongeTheme.spacingM)
                }
                .sheet(item: $selectedMarker) { marker in
                    MarkerContextSheet(marker: marker, fullTranscript: recording.transcriptText)
                }
            }
        }
    }

    private var markersSummary: some View {
        HStack(spacing: SpongeTheme.spacingM) {
            ForEach(IntentMarkerType.allCases) { type in
                let count = recording.intentMarkers.filter { $0.type == type }.count
                if count > 0 {
                    MarkerCountBadge(type: type, count: count)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: SpongeTheme.spacingM) {
            Spacer()

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

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(SpongeTheme.spacingL)
    }

    // MARK: - Badge Count

    private func badgeCount(for tab: DetailTab) -> Int? {
        switch tab {
        case .transcript:
            return nil
        case .summaries:
            var count = 0
            if recording.enhancedSummary?.generalOverview != nil { count += 1 }
            if recording.enhancedSummary?.confusionFocused != nil { count += 1 }
            if recording.enhancedSummary?.examOriented != nil { count += 1 }
            return count > 0 ? count : nil
        case .recall:
            let count = recording.recallPrompts?.questions.count ?? 0
            return count > 0 ? count : nil
        case .markers:
            let count = recording.intentMarkers.count
            return count > 0 ? count : nil
        }
    }
}

// MARK: - Supporting Views

private struct TabSegmentButton: View {
    let tab: RecordingDetailView.DetailTab
    let isSelected: Bool
    let badgeCount: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))

                if let count = badgeCount {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(SpongeTheme.coral))
                }
            }
            .foregroundColor(isSelected ? SpongeTheme.coral : .secondary)
            .padding(.horizontal, SpongeTheme.spacingS)
            .padding(.vertical, SpongeTheme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                    .fill(isSelected ? SpongeTheme.coral.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MarkerTimelineRow: View {
    let marker: IntentMarker
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: SpongeTheme.spacingM) {
                // Timestamp
                Text(marker.formattedTimestamp)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)

                // Type indicator
                Circle()
                    .fill(markerColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: marker.type.icon)
                            .font(.caption)
                        Text(marker.type.displayName)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(markerColor)

                    if let snapshot = marker.transcriptSnapshot {
                        Text("\"...\(snapshot)...\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Click to expand indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, SpongeTheme.spacingS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                .fill(Color.primaryBackground.opacity(0.001))
        )
        .onHover { isHovered in
            NSCursor.pointingHand.push()
        }
    }

    private var markerColor: Color {
        switch marker.type {
        case .confused:
            return .orange
        case .important:
            return .red
        case .examRelevant:
            return .yellow
        case .reviewLater:
            return .blue
        }
    }
}

private struct MarkerCountBadge: View {
    let type: IntentMarkerType
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 12))
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, SpongeTheme.spacingS)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
    }

    private var badgeColor: Color {
        switch type {
        case .confused:
            return .orange
        case .important:
            return .red
        case .examRelevant:
            return .yellow
        case .reviewLater:
            return .blue
        }
    }
}

// MARK: - Marker Context Sheet

private struct MarkerContextSheet: View {
    let marker: IntentMarker
    let fullTranscript: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: marker.type.icon)
                            .font(.headline)
                            .foregroundColor(markerColor)
                        Text(marker.type.displayName)
                            .font(.headline)
                            .foregroundColor(markerColor)
                    }

                    Text("at \(marker.formattedTimestamp)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(SpongeTheme.spacingM)

            Divider()

            // Context view
            ScrollView {
                VStack(alignment: .leading, spacing: SpongeTheme.spacingM) {
                    if let context = extractContext() {
                        // Before context
                        if !context.before.isEmpty {
                            Text(context.before)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }

                        // Highlighted snapshot
                        if let snapshot = marker.transcriptSnapshot, !snapshot.isEmpty {
                            Text(snapshot)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                                .padding(SpongeTheme.spacingS)
                                .background(
                                    RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                                        .fill(markerColor.opacity(0.15))
                                )
                                .lineSpacing(4)
                        }

                        // After context
                        if !context.after.isEmpty {
                            Text(context.after)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    } else {
                        // Fallback if context extraction fails
                        VStack(spacing: SpongeTheme.spacingS) {
                            if let snapshot = marker.transcriptSnapshot {
                                Text("Marked content:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(snapshot)
                                    .font(.body)
                                    .lineSpacing(4)
                                    .padding(SpongeTheme.spacingS)
                                    .background(
                                        RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                                            .fill(markerColor.opacity(0.15))
                                    )
                            }

                            Text("Full transcript not available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(SpongeTheme.spacingM)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var markerColor: Color {
        switch marker.type {
        case .confused:
            return .orange
        case .important:
            return .red
        case .examRelevant:
            return .yellow
        case .reviewLater:
            return .blue
        }
    }

    /// Extracts context around the marker from the full transcript
    private func extractContext() -> (before: String, after: String)? {
        guard !fullTranscript.isEmpty,
              let snapshot = marker.transcriptSnapshot,
              !snapshot.isEmpty else {
            return nil
        }

        // Find the snapshot in the full transcript
        guard let range = fullTranscript.range(of: snapshot, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }

        let beforeIndex = range.lowerBound
        let afterIndex = range.upperBound

        // Extract ~150 words before
        let beforeText = String(fullTranscript[..<beforeIndex])
        let beforeWords = beforeText.split(separator: " ")
        let beforeContext = beforeWords.suffix(150).joined(separator: " ")

        // Extract ~150 words after
        let afterText = String(fullTranscript[afterIndex...])
        let afterWords = afterText.split(separator: " ")
        let afterContext = afterWords.prefix(150).joined(separator: " ")

        return (
            before: beforeContext.isEmpty ? "" : beforeContext + " ",
            after: afterContext.isEmpty ? "" : " " + afterContext
        )
    }
}

#Preview {
    RecordingDetailView(
        recording: SDRecording(
            classId: UUID(),
            duration: 3600,
            audioFileName: "test.m4a",
            transcriptText: "Today we discussed the fundamentals of algorithms...",
            userNotes: "# Important Notes\n\n- Big O notation\n- Tree structures",
            intentMarkers: [
                IntentMarker(type: .confused, timestamp: 120, transcriptSnapshot: "the time complexity of recursive functions"),
                IntentMarker(type: .important, timestamp: 360, transcriptSnapshot: "this will be on the exam"),
                IntentMarker(type: .examRelevant, timestamp: 600, transcriptSnapshot: "master theorem")
            ],
            enhancedSummary: EnhancedSummary(
                generalOverview: "This lecture covered algorithm analysis...",
                confusionFocused: "Recursion can be confusing because...",
                examOriented: "Key exam topics: Big O, Master Theorem..."
            ),
            recallPrompts: RecallPrompts(questions: [
                RecallQuestion(question: "What is Big O notation?", type: .definition, suggestedAnswer: "Big O describes the upper bound of algorithm time complexity.")
            ])
        ),
        className: "CS 201"
    )
    .environmentObject(RecordingViewModel())
}
