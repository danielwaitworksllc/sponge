import SwiftUI

struct RecordingsListView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16)

                    Text("Recordings")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let count = recordingCount, count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }

                    Spacer()

                    if let selectedClass = classViewModel.selectedClass {
                        Text(selectedClass.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(SpongeTheme.cream)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Content — hidden when collapsed
            if !isCollapsed {
                if classViewModel.selectedClass == nil {
                    emptyStateView(
                        icon: "folder",
                        title: "No Class Selected",
                        message: "Select a class to view its recordings"
                    )
                } else if classViewModel.recordingsForSelectedClass().isEmpty {
                    emptyStateView(
                        icon: "waveform",
                        title: "No Recordings",
                        message: "Start recording to create your first transcript"
                    )
                } else {
                    List {
                        ForEach(classViewModel.recordingsForSelectedClass()) { recording in
                            RecordingRowView(recording: recording, classViewModel: classViewModel)
                        }
                        .onDelete(perform: deleteRecordings)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(SpongeTheme.cream)
                }
            }
        }
    }

    private var recordingCount: Int? {
        guard classViewModel.selectedClass != nil else { return nil }
        return classViewModel.recordingsForSelectedClass().count
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(SpongeTheme.coral.opacity(0.3))

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func deleteRecordings(at offsets: IndexSet) {
        let recordings = classViewModel.recordingsForSelectedClass()
        for index in offsets {
            classViewModel.deleteRecording(recordings[index])
        }
    }
}

// MARK: - Recording Row View

struct RecordingRowView: View {
    let recording: SDRecording
    @ObservedObject var classViewModel: ClassViewModel
    @EnvironmentObject private var recordingViewModel: RecordingViewModel
    @State private var showingDetail = false
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(SpongeTheme.cream)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(SpongeTheme.coral.opacity(0.3), lineWidth: 1.5)
                        )

                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundColor(SpongeTheme.coral)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recording.name)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(recording.formattedDuration)
                            .font(.caption)
                            .foregroundColor(SpongeTheme.coral)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SpongeTheme.cream)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(SpongeTheme.coral.opacity(0.3), lineWidth: 1)
                            )
                    }

                    HStack(spacing: 6) {
                        Text(recording.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if recording.pdfExported {
                            Label("Exported", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        // Marker count badge
                        if !recording.intentMarkers.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 8))
                                Text("\(recording.intentMarkers.count)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                        }

                        // Recall questions badge
                        if let questions = recording.recallPrompts?.questions, !questions.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 8))
                                Text("\(questions.count)")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(4)
                        }

                        Spacer()

                        Text("\(recording.transcriptText.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Action buttons
                HStack(spacing: 8) {
                    // Show in Finder button (only if PDF exported)
                    if recording.pdfExported {
                        Button {
                            revealPDFInFinder()
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Show PDF in Finder")
                    }

                    // Delete button
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Delete recording")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Delete Recording?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                classViewModel.deleteRecording(recording)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \"\(recording.name)\" and its transcript. This action cannot be undone.")
        }
        .contextMenu {
            Button {
                showingDetail = true
            } label: {
                Label("View Transcript", systemImage: "doc.text")
            }

            if recording.pdfExported {
                Button {
                    revealPDFInFinder()
                } label: {
                    Label("Show PDF in Finder", systemImage: "folder")
                }
            }

            Button {
                showingEditSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                classViewModel.deleteRecording(recording)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                classViewModel.deleteRecording(recording)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                showingEditSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showingDetail) {
            if let classModel = classViewModel.classes.first(where: { $0.id == recording.classId }) {
                RecordingDetailView(recording: recording, className: classModel.name)
            } else {
                RecordingDetailView(recording: recording, className: "Unknown Class")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            RecordingEditorView(recording: recording, classViewModel: classViewModel)
        }
    }

    private func revealPDFInFinder() {
        guard let classModel = classViewModel.classes.first(where: { $0.id == recording.classId }) else {
            return
        }

        // Generate PDF filename matching the format used in RecordingViewModel.generateFileName
        let pdfFileName = generatePDFFileName(className: classModel.name, date: recording.date)
        var pdfURL: URL?

        // Resolve local folder
        if let localURL = classModel.resolveFolder() {
            pdfURL = localURL.appendingPathComponent(pdfFileName)
        }

        // Reveal in Finder (macOS) or Files (iOS)
        if let pdfURL = pdfURL, FileManager.default.fileExists(atPath: pdfURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([pdfURL])
        }
    }

    /// Generates PDF filename matching RecordingViewModel.generateFileName format
    private func generatePDFFileName(className: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datePart = dateFormatter.string(from: date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h-mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let timePart = timeFormatter.string(from: date)

        return "\(className)_\(datePart)_\(timePart).pdf"
    }
}

// MARK: - Transcript Detail View

struct TranscriptDetailView: View {
    let recording: SDRecording
    @ObservedObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metadata card
                    VStack(spacing: 12) {
                        MetadataRow(label: "Date", value: recording.formattedDate)
                        Divider()
                        MetadataRow(label: "Duration", value: recording.formattedDuration)
                        Divider()
                        MetadataRow(label: "Words", value: "\(recording.transcriptText.split(separator: " ").count)")

                        if recording.pdfExported {
                            Divider()
                            HStack {
                                Text("Status")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Label("PDF Exported", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(16)
                    .background(Color.secondaryBackground)
                    .cornerRadius(12)

                    // Transcript
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transcript")
                            .font(.headline)

                        Text(recording.transcriptText.isEmpty ? "No transcript available" : recording.transcriptText)
                            .font(.body)
                            .foregroundColor(recording.transcriptText.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .background(Color.primaryBackground)
            .navigationTitle(recording.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                RecordingEditorView(recording: recording, classViewModel: classViewModel)
            }
        }
        .frame(minWidth: 550, minHeight: 450)
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.subheadline)
    }
}

// MARK: - Recording Editor View

struct RecordingEditorView: View {
    let recording: SDRecording
    @ObservedObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recording Name", text: $name)
                        .font(.body)
                } header: {
                    Text("Name")
                }

                Section {
                    MetadataRow(label: "Date", value: recording.formattedDate)
                    MetadataRow(label: "Duration", value: recording.formattedDuration)
                    MetadataRow(label: "Words", value: "\(recording.transcriptText.split(separator: " ").count)")

                    HStack {
                        Text("PDF Exported")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: recording.pdfExported ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(recording.pdfExported ? .green : .secondary)
                    }
                    .font(.subheadline)
                } header: {
                    Text("Details")
                }

                Section {
                    Text(recording.transcriptText.isEmpty ? "No transcript available" : String(recording.transcriptText.prefix(300)) + (recording.transcriptText.count > 300 ? "…" : ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(6)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Rename Recording")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = recording.name
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private func saveChanges() {
        var updatedRecording = recording
        updatedRecording.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        classViewModel.updateRecording(updatedRecording)
        dismiss()
    }
}

#Preview {
    RecordingsListView(isCollapsed: .constant(false))
        .environmentObject(ClassViewModel())
}
