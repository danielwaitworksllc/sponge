import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @ObservedObject var recordingViewModel: RecordingViewModel
    @State private var showingPermissionAlert = false
    @State private var isConfirmingStop = false
    @State private var showFullTranscript = false
    @State private var ringAnimation = false

    var body: some View {
        VStack(spacing: 0) {
            if recordingViewModel.isRecording {
                recordingActiveView
            } else {
                recordingIdleView
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable microphone and speech recognition permissions in System Settings.")
        }
    }

    // MARK: - Recording Active View

    private var recordingActiveView: some View {
        VStack(spacing: 12) {
            // Compact header with timer and class name
            compactHeader

            // Intent marker bar for signaling confusion, importance, etc.
            IntentMarkerBar(
                onMarkerTapped: { type in
                    recordingViewModel.addIntentMarker(type: type)
                },
                recentMarkers: recordingViewModel.intentMarkers
            )

            // Live transcript with integrated controls
            transcriptWithControls

            // User notes - fills remaining space
            userNotesInput
        }
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        HStack {
            // Recording indicator and timer
            HStack(spacing: 8) {
                Circle()
                    .fill(recordingViewModel.isPaused ? Color.gray : SpongeTheme.coral)
                    .frame(width: 10, height: 10)
                    .modifier(PulsingModifier(isActive: !recordingViewModel.isPaused))

                Text(recordingViewModel.formattedDuration)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Spacer()

            // Class name (clickable to change)
            if let selectedClass = classViewModel.selectedClass {
                Menu {
                    ForEach(classViewModel.classes) { classModel in
                        Button {
                            classViewModel.selectedClass = classModel
                        } label: {
                            HStack {
                                Text(classModel.name)
                                if classModel.id == selectedClass.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedClass.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(SpongeTheme.subtleFill)
                    .cornerRadius(SpongeTheme.cornerRadiusXS)
                }
                .menuStyle(.borderlessButton)
                .help("Change class")
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Transcript with Controls

    private var transcriptWithControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with controls
            HStack(spacing: 12) {
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(recordingViewModel.isPaused ? Color.gray : Color.red)
                        .frame(width: 6, height: 6)
                        .modifier(PulsingModifier(isActive: !recordingViewModel.isPaused))

                    Text(recordingViewModel.isPaused ? "Paused" : "Live Transcription")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Recording time
                Text(recordingViewModel.formattedDuration)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SpongeTheme.subtleFill)
                    .cornerRadius(SpongeTheme.cornerRadiusXS)

                // Word count
                Text("\(wordCount) words")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SpongeTheme.subtleFill)
                    .cornerRadius(SpongeTheme.cornerRadiusXS)

                // "What did I miss" button
                Button {
                    Task {
                        await recordingViewModel.requestCatchUpSummary()
                    }
                } label: {
                    HStack(spacing: 3) {
                        if recordingViewModel.isCatchUpLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: recordingViewModel.lastCatchUpSummary != nil ? "checkmark.circle.fill" : "brain.head.profile")
                                .font(.caption2)
                        }
                        Text(recordingViewModel.lastCatchUpSummary != nil ? "Summary" : "Catch Up")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SpongeTheme.coral)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(recordingViewModel.isCatchUpLoading)
                .popover(isPresented: Binding(
                    get: { recordingViewModel.lastCatchUpSummary != nil && !recordingViewModel.isCatchUpLoading },
                    set: { if !$0 { recordingViewModel.lastCatchUpSummary = nil } }
                )) {
                    if let summary = recordingViewModel.lastCatchUpSummary {
                        CompactCatchUpPopover(
                            summary: summary,
                            onDismiss: { recordingViewModel.lastCatchUpSummary = nil }
                        )
                    }
                }

                // Expand/collapse button
                if lineCount > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFullTranscript.toggle()
                        }
                    } label: {
                        Image(systemName: showFullTranscript ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 16)

                // Inline controls
                if isConfirmingStop {
                    inlineConfirmControls
                } else {
                    inlineRecordingControls
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SpongeTheme.subtleBackground)

            Divider()

            // Transcript content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if recordingViewModel.transcribedText.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Listening...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                        } else {
                            Text(displayText)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .id("transcriptEnd")
                        }
                    }
                }
                .onChange(of: recordingViewModel.transcribedText) { _, _ in
                    if !showFullTranscript {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("transcriptEnd", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(height: showFullTranscript ? 200 : 100)
        .background(SpongeTheme.surfacePrimary)
        .cornerRadius(SpongeTheme.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                .stroke(recordingViewModel.isPaused ? SpongeTheme.subtleBorder : SpongeTheme.coral.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Inline Recording Controls

    private var inlineRecordingControls: some View {
        HStack(spacing: 8) {
            // Pause/Resume button
            Button {
                if recordingViewModel.isPaused {
                    recordingViewModel.resumeRecording()
                } else {
                    recordingViewModel.pauseRecording()
                }
            } label: {
                Image(systemName: recordingViewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                    .background(SpongeTheme.coral)
                    .cornerRadius(SpongeTheme.cornerRadiusXS)
            }
            .buttonStyle(.plain)
            .help(recordingViewModel.isPaused ? "Resume" : "Pause")

            // Stop button
            Button {
                // Pause recording/transcription while confirming
                if !recordingViewModel.isPaused {
                    recordingViewModel.pauseRecording()
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConfirmingStop = true
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                    .background(Color.red)
                    .cornerRadius(SpongeTheme.cornerRadiusXS)
            }
            .buttonStyle(.plain)
            .help("Stop Recording")
        }
    }

    // MARK: - Inline Confirm Controls

    private var inlineConfirmControls: some View {
        HStack(spacing: 6) {
            // Back button - resume recording if we paused it
            Button {
                recordingViewModel.resumeRecording()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConfirmingStop = false
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                    .background(SpongeTheme.subtleBorder)
                    .cornerRadius(SpongeTheme.cornerRadiusXS)
            }
            .buttonStyle(.plain)
            .help("Back")

            // Save button
            Button {
                if let selectedClass = classViewModel.selectedClass {
                    recordingViewModel.stopRecording(classModel: selectedClass, classViewModel: classViewModel)
                }
                isConfirmingStop = false
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Save")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(height: SpongeTheme.controlSizeS)
                .background(SpongeTheme.coral)
                .cornerRadius(SpongeTheme.cornerRadiusXS)
            }
            .buttonStyle(.plain)
            .help("Save Recording")

            // Discard button
            Button {
                recordingViewModel.cancelRecording()
                isConfirmingStop = false
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(SpongeTheme.cornerRadiusXS)
            }
            .buttonStyle(.plain)
            .help("Discard")
        }
        .animation(.easeInOut(duration: 0.2), value: isConfirmingStop)
    }

    // MARK: - Recording Idle View

    private var recordingIdleView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Duration (shows 00:00:00 when idle)
            Text(recordingViewModel.formattedDuration)
                .font(.system(size: 44, weight: .light, design: .monospaced))
                .foregroundColor(.secondary)

            // Record button
            recordButton

            // Status/warning text
            statusText

            Spacer()
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            startRecordingWithPermissionCheck()
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .stroke(SpongeTheme.coral.opacity(ringAnimation ? 0.0 : 0.3), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringAnimation ? 1.4 : 1.0)

                    // Middle ring
                    Circle()
                        .stroke(SpongeTheme.coral.opacity(0.3), lineWidth: 3)
                        .frame(width: 100, height: 100)

                    // Inner filled circle
                    Circle()
                        .fill(SpongeTheme.primaryGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: SpongeTheme.shadowM, radius: 8, x: 0, y: 4)

                    // Microphone icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }

                // Class selector
                if let selectedClass = classViewModel.selectedClass {
                    classSelector(for: selectedClass)
                } else {
                    Text("Select a class to record")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(classViewModel.selectedClass == nil)
        .opacity(classViewModel.selectedClass == nil ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                ringAnimation = true
            }
        }
    }

    private func classSelector(for selectedClass: SDClass) -> some View {
        Menu {
            ForEach(classViewModel.classes) { classModel in
                Button {
                    classViewModel.selectedClass = classModel
                } label: {
                    HStack {
                        Text(classModel.name)
                        if classModel.id == selectedClass.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedClass.name)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(SpongeTheme.coral)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(SpongeTheme.cream)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SpongeTheme.coral.opacity(0.3), lineWidth: 1.5)
            )
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Status Text

    @ViewBuilder
    private var statusText: some View {
        if let error = recordingViewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundColor(.red)
        } else if classViewModel.selectedClass == nil {
            Label("Add a class to start recording", systemImage: "plus.circle")
                .font(.subheadline)
                .foregroundColor(.orange)
        } else if let selectedClass = classViewModel.selectedClass, !selectedClass.isConfigurationValid {
            Label("Configure save location in Settings", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundColor(.orange)
        } else {
            Text("Tap to start recording")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - User Notes Input

    private var userNotesInput: some View {
        ExpandingMarkdownNotesEditor(text: $recordingViewModel.userNotes, noteTitle: $recordingViewModel.userNotesTitle)
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        recordingViewModel.transcribedText.split(separator: " ").count
    }

    private var lineCount: Int {
        recordingViewModel.transcribedText.components(separatedBy: "\n").count
    }

    private var displayText: String {
        if showFullTranscript {
            return recordingViewModel.transcribedText
        }

        let lines = recordingViewModel.transcribedText.components(separatedBy: "\n")
        if lines.count <= 3 {
            return recordingViewModel.transcribedText
        }

        let lastLines = lines.suffix(3)
        return "…\n" + lastLines.joined(separator: "\n")
    }

    // MARK: - Methods

    private func startRecordingWithPermissionCheck() {
        let doStart = {
            if self.recordingViewModel.permissionsGranted {
                self.recordingViewModel.startRecording()
            } else {
                self.recordingViewModel.requestPermissions { granted in
                    if granted {
                        self.recordingViewModel.startRecording()
                    } else {
                        self.showingPermissionAlert = true
                    }
                }
            }
        }

        doStart()
    }

}

// MARK: - Expanding Markdown Notes Editor (fills available space)

struct ExpandingMarkdownNotesEditor: View {
    @Binding var text: String
    @Binding var noteTitle: String
    @FocusState private var isTitleFocused: Bool
    @State private var saveState: SaveState = .idle

    enum SaveState: Equatable {
        case idle, saving, saved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with title and word count
            headerSection

            Divider()

            // Formatting toolbar
            formattingToolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(SpongeTheme.subtleBackground)

            Divider()

            // Notes text editor - fills remaining space
            LiveMarkdownEditor(text: $text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SpongeTheme.surfacePrimary)
        .cornerRadius(SpongeTheme.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                .stroke(SpongeTheme.subtleBorder, lineWidth: 1)
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)

            // Editable title
            TextField("Note Title (optional)", text: $noteTitle)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .focused($isTitleFocused)

            Spacer()

            // Auto-save indicator
            HStack(spacing: 4) {
                switch saveState {
                case .idle:
                    EmptyView()
                case .saving:
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Saving…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Saved")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: saveState == .saved)

            Text("\(wordCount) words")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(SpongeTheme.subtleFill)
                .cornerRadius(SpongeTheme.cornerRadiusXS)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SpongeTheme.subtleBackground)
        .onChange(of: text) { _, _ in
            triggerSave()
        }
        .onChange(of: noteTitle) { _, _ in
            triggerSave()
        }
    }

    private func triggerSave() {
        saveState = .saving
        // Debounce: wait 0.8s of no changes before marking saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            saveState = .saved
            // Hide the indicator after 2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if saveState == .saved {
                    saveState = .idle
                }
            }
        }
    }

    // MARK: - Formatting Toolbar

    private var formattingToolbar: some View {
        HStack(spacing: 4) {
            // Heading buttons
            FormatButtonWithLabel(label: "H1", tooltip: "Heading 1") {
                insertMarkdown(prefix: "# ", suffix: "")
            }
            FormatButtonWithLabel(label: "H2", tooltip: "Heading 2") {
                insertMarkdown(prefix: "## ", suffix: "")
            }
            FormatButtonWithLabel(label: "H3", tooltip: "Heading 3") {
                insertMarkdown(prefix: "### ", suffix: "")
            }

            toolbarDivider

            // Text formatting
            FormatButton(icon: "bold", tooltip: "Bold (Cmd+B)") {
                insertMarkdown(prefix: "**", suffix: "**")
            }
            FormatButton(icon: "italic", tooltip: "Italic (Cmd+I)") {
                insertMarkdown(prefix: "_", suffix: "_")
            }
            FormatButton(icon: "strikethrough", tooltip: "Strikethrough (Cmd+Shift+X)") {
                insertMarkdown(prefix: "~~", suffix: "~~")
            }
            FormatButton(icon: "underline", tooltip: "Underline (Cmd+U)") {
                insertMarkdown(prefix: "<u>", suffix: "</u>")
            }
            FormatButton(icon: "highlighter", tooltip: "Highlight") {
                insertMarkdown(prefix: "==", suffix: "==")
            }

            toolbarDivider

            // Lists
            FormatButton(icon: "list.bullet", tooltip: "Bullet List") {
                insertMarkdown(prefix: "- ", suffix: "", isLinePrefix: true)
            }
            FormatButton(icon: "list.number", tooltip: "Numbered List") {
                insertMarkdown(prefix: "1. ", suffix: "", isLinePrefix: true)
            }
            FormatButton(icon: "checklist", tooltip: "Checklist") {
                insertMarkdown(prefix: "- [ ] ", suffix: "", isLinePrefix: true)
            }

            toolbarDivider

            // Block elements
            FormatButton(icon: "increase.indent", tooltip: "Indent (Tab)") {
                NotificationCenter.default.post(name: .indentLine, object: nil, userInfo: ["direction": "indent"])
            }
            FormatButton(icon: "decrease.indent", tooltip: "Outdent (Shift+Tab)") {
                NotificationCenter.default.post(name: .indentLine, object: nil, userInfo: ["direction": "outdent"])
            }
            FormatButton(icon: "minus", tooltip: "Horizontal Rule") {
                insertMarkdown(prefix: "\n---\n", suffix: "", isLinePrefix: false)
            }
            FormatButton(icon: "text.quote", tooltip: "Block Quote") {
                insertMarkdown(prefix: "> ", suffix: "", isLinePrefix: true)
            }

            Spacer()

            // Keyboard hints
            Text("Cmd+B bold · Cmd+I italic")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
        }
    }

    private var toolbarDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 3)
    }

    // MARK: - Computed Properties

    private var wordCount: Int {
        text.split(separator: " ").count
    }

    // MARK: - Formatting Actions

    private func insertMarkdown(prefix: String, suffix: String, isLinePrefix: Bool = false) {
        NotificationCenter.default.post(
            name: .insertMarkdown,
            object: nil,
            userInfo: ["prefix": prefix, "suffix": suffix, "isLinePrefix": isLinePrefix]
        )
    }
}

// MARK: - Compact Catch-Up Popover

struct CompactCatchUpPopover: View {
    let summary: CatchUpSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(SpongeTheme.coral)
                    .font(.caption)
                Text("Catch-Up")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Time range
            Text(summary.formattedRange)
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()

            // Summary content (limited to 3 lines)
            Text(summary.summary)
                .font(.caption)
                .foregroundColor(.primary)
                .lineSpacing(3)
                .lineLimit(5)
        }
        .padding(SpongeTheme.spacingS)
        .frame(width: 240)
    }
}

// MARK: - Pulsing Animation Modifier

struct PulsingModifier: ViewModifier {
    var isActive: Bool = true
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive && isPulsing ? 0.4 : 1.0)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}

// MARK: - Compact Recording Bar

/// A slim bar shown during active recording so the user can browse past recordings.
/// Tapping "Expand" returns to the full recording view with transcript and notes.
struct CompactRecordingBar: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @ObservedObject var recordingViewModel: RecordingViewModel
    var onExpand: () -> Void

    @State private var isConfirmingStop = false

    var body: some View {
        HStack(spacing: 12) {
            // Pulsing recording dot
            Circle()
                .fill(recordingViewModel.isPaused ? Color.gray : SpongeTheme.coral)
                .frame(width: 10, height: 10)
                .modifier(PulsingModifier(isActive: !recordingViewModel.isPaused))

            // Timer
            Text(recordingViewModel.formattedDuration)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)

            // Class name
            if let selectedClass = classViewModel.selectedClass {
                Text(selectedClass.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Word count
            Text("\(recordingViewModel.transcribedText.split(separator: " ").count) words")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(SpongeTheme.subtleFill)
                .cornerRadius(SpongeTheme.cornerRadiusXS)

            Spacer()

            if isConfirmingStop {
                // Confirm stop controls
                HStack(spacing: 6) {
                    Button {
                        recordingViewModel.resumeRecording()
                        withAnimation { isConfirmingStop = false }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                            .background(SpongeTheme.subtleBorder)
                            .cornerRadius(SpongeTheme.cornerRadiusXS)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let selectedClass = classViewModel.selectedClass {
                            recordingViewModel.stopRecording(classModel: selectedClass, classViewModel: classViewModel)
                        }
                        isConfirmingStop = false
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Save")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .frame(height: SpongeTheme.controlSizeS)
                        .background(SpongeTheme.coral)
                        .cornerRadius(SpongeTheme.cornerRadiusXS)
                    }
                    .buttonStyle(.plain)

                    Button {
                        recordingViewModel.cancelRecording()
                        isConfirmingStop = false
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(SpongeTheme.cornerRadiusXS)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Normal controls
                HStack(spacing: 6) {
                    // Expand button — go back to full recording view
                    Button(action: onExpand) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.expand.vertical")
                                .font(.system(size: 11))
                            Text("Notes")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(SpongeTheme.coral)
                        .padding(.horizontal, 8)
                        .frame(height: SpongeTheme.controlSizeS)
                        .background(SpongeTheme.coral.opacity(0.12))
                        .cornerRadius(SpongeTheme.cornerRadiusXS)
                    }
                    .buttonStyle(.plain)
                    .help("Expand to see transcript and notes")

                    // Pause/Resume
                    Button {
                        if recordingViewModel.isPaused {
                            recordingViewModel.resumeRecording()
                        } else {
                            recordingViewModel.pauseRecording()
                        }
                    } label: {
                        Image(systemName: recordingViewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                            .background(SpongeTheme.coral)
                            .cornerRadius(SpongeTheme.cornerRadiusXS)
                    }
                    .buttonStyle(.plain)

                    // Stop
                    Button {
                        if !recordingViewModel.isPaused {
                            recordingViewModel.pauseRecording()
                        }
                        withAnimation { isConfirmingStop = true }
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: SpongeTheme.controlSizeS, height: SpongeTheme.controlSizeS)
                            .background(Color.red)
                            .cornerRadius(SpongeTheme.cornerRadiusXS)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .fill(SpongeTheme.coral.opacity(0.3))
                .frame(height: 2),
            alignment: .bottom
        )
    }
}


#Preview {
    RecordingView(recordingViewModel: RecordingViewModel())
        .environmentObject(ClassViewModel())
}
