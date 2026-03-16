import SwiftUI

/// View for practicing recall with generated questions
struct RecallPromptsView: View {
    @Bindable var recording: SDRecording

    @State private var viewMode: ViewMode = .list
    @State private var currentCardIndex = 0
    @State private var isFlipped = false
    @State private var revealedQuestions: Set<UUID> = []

    private enum ViewMode: String, CaseIterable {
        case list = "List"
        case flashcard = "Flashcard"

        var icon: String {
            switch self {
            case .list:
                return "list.bullet"
            case .flashcard:
                return "rectangle.stack"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with mode toggle
            header

            Divider()

            // Content based on mode
            if let prompts = recording.recallPrompts, !prompts.questions.isEmpty {
                switch viewMode {
                case .list:
                    listView(prompts: prompts)
                case .flashcard:
                    flashcardView(prompts: prompts)
                }
            } else {
                emptyState
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Recall Practice")
                .font(.headline)

            Spacer()

            // View mode picker
            Picker("View Mode", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(SpongeTheme.spacingM)
    }

    // MARK: - List View

    private func listView(prompts: RecallPrompts) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpongeTheme.spacingL) {
                ForEach(RecallQuestionType.allCases) { type in
                    let questionsOfType = prompts.questions.filter { $0.type == type }
                    if !questionsOfType.isEmpty {
                        QuestionGroupView(
                            type: type,
                            questions: questionsOfType,
                            revealedQuestions: $revealedQuestions
                        )
                    }
                }
            }
            .padding(SpongeTheme.spacingM)
        }
    }

    // MARK: - Flashcard View

    private func flashcardView(prompts: RecallPrompts) -> some View {
        VStack(spacing: SpongeTheme.spacingM) {
            // Progress indicator
            progressIndicator(total: prompts.questions.count)

            Spacer()

            // Flashcard
            if currentCardIndex < prompts.questions.count {
                FlashcardView(
                    question: prompts.questions[currentCardIndex],
                    isFlipped: $isFlipped
                )
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            if value.translation.width < -50 {
                                // Swipe left - next card
                                nextCard(total: prompts.questions.count)
                            } else if value.translation.width > 50 {
                                // Swipe right - previous card
                                previousCard()
                            }
                        }
                )
            }

            Spacer()

            // Navigation buttons
            flashcardNavigation(total: prompts.questions.count)
        }
        .padding(SpongeTheme.spacingM)
    }

    private func progressIndicator(total: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == currentCardIndex ? SpongeTheme.coral : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func flashcardNavigation(total: Int) -> some View {
        HStack(spacing: SpongeTheme.spacingL) {
            Button {
                previousCard()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(currentCardIndex > 0 ? SpongeTheme.coral : .secondary.opacity(0.3))
            }
            .disabled(currentCardIndex == 0)
            .buttonStyle(.plain)

            Text("\(currentCardIndex + 1) / \(total)")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 80)

            Button {
                nextCard(total: total)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(currentCardIndex < total - 1 ? SpongeTheme.coral : .secondary.opacity(0.3))
            }
            .disabled(currentCardIndex >= total - 1)
            .buttonStyle(.plain)
        }
    }

    private func nextCard(total: Int) {
        if currentCardIndex < total - 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentCardIndex += 1
                isFlipped = false
            }
        }
    }

    private func previousCard() {
        if currentCardIndex > 0 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentCardIndex -= 1
                isFlipped = false
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SpongeTheme.spacingM) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Recall Questions")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Enable recall prompts generation in settings to practice retention after lectures.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpongeTheme.spacingL)

            Spacer()
        }
    }
}

// MARK: - Question Group View

private struct QuestionGroupView: View {
    let type: RecallQuestionType
    let questions: [RecallQuestion]
    @Binding var revealedQuestions: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
            // Type header
            HStack(spacing: SpongeTheme.spacingS) {
                Image(systemName: type.icon)
                    .foregroundColor(typeColor)
                Text(type.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(typeColor)

                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Questions
            ForEach(questions) { question in
                QuestionRow(
                    question: question,
                    isRevealed: revealedQuestions.contains(question.id),
                    onToggle: {
                        if revealedQuestions.contains(question.id) {
                            revealedQuestions.remove(question.id)
                        } else {
                            revealedQuestions.insert(question.id)
                        }
                    }
                )
            }
        }
    }

    private var typeColor: Color {
        switch type {
        case .definition:
            return .blue
        case .conceptual:
            return .purple
        case .applied:
            return .green
        case .connection:
            return .orange
        }
    }
}

// MARK: - Question Row

private struct QuestionRow: View {
    let question: RecallQuestion
    let isRevealed: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
            // Question
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: SpongeTheme.spacingS) {
                    Image(systemName: isRevealed ? "eye.fill" : "eye.slash")
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    Text(question.question)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Answer (if revealed)
            if isRevealed, let answer = question.suggestedAnswer {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
                    .padding(.top, 4)
            }
        }
        .padding(SpongeTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                .fill(SpongeTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                .stroke(SpongeTheme.subtleBorder, lineWidth: 1)
        )
    }
}

// MARK: - Flashcard View

private struct FlashcardView: View {
    let question: RecallQuestion
    @Binding var isFlipped: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }) {
            ZStack {
                // Back (answer)
                cardBack
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 0 : -180),
                        axis: (x: 0, y: 1, z: 0)
                    )

                // Front (question)
                cardFront
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var cardFront: some View {
        VStack(spacing: SpongeTheme.spacingM) {
            // Type badge
            HStack {
                Image(systemName: question.type.icon)
                Text(question.type.displayName)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.secondary)

            Spacer()

            Text(question.question)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)

            Spacer()

            Text("Tap to reveal answer")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(SpongeTheme.spacingL)
        .frame(maxWidth: .infinity, maxHeight: 350)
        .background(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusL)
                .fill(SpongeTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusL)
                .stroke(SpongeTheme.subtleBorder, lineWidth: 1)
        )
    }

    private var cardBack: some View {
        VStack(spacing: SpongeTheme.spacingM) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Answer")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let answer = question.suggestedAnswer {
                Text(answer)
                    .font(.body)
                    .multilineTextAlignment(.center)
            } else {
                Text("No suggested answer available")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Tap to see question")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(SpongeTheme.spacingL)
        .frame(maxWidth: .infinity, maxHeight: 350)
        .background(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusL)
                .fill(SpongeTheme.coral.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusL)
                .stroke(SpongeTheme.subtleBorder, lineWidth: 1)
        )
    }
}

#Preview {
    RecallPromptsView(
        recording: SDRecording(
            classId: UUID(),
            audioFileName: "test.m4a",
            recallPrompts: RecallPrompts(questions: [
                RecallQuestion(question: "What is a binary search tree?", type: .definition, suggestedAnswer: "A binary search tree is a data structure where each node has at most two children, with all left descendants less than the node and all right descendants greater."),
                RecallQuestion(question: "Why is tree balancing important?", type: .conceptual, suggestedAnswer: "Balancing maintains O(log n) operations by preventing the tree from degenerating into a linked list."),
                RecallQuestion(question: "How would you implement a rotation in an AVL tree?", type: .applied, suggestedAnswer: "Identify the imbalance type (LL, RR, LR, RL), then perform single or double rotations to restore balance."),
                RecallQuestion(question: "How do BSTs relate to sorting algorithms?", type: .connection, suggestedAnswer: "An in-order traversal of a BST produces sorted output, connecting tree structures to efficient sorting.")
            ])
        )
    )
}
