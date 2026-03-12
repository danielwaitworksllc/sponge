import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("autoGenerateClassNotes") private var autoGenerateClassNotes = false
    @AppStorage("realtimeTranscription") private var realtimeTranscription = true
    @AppStorage("generateRecallPrompts") private var generateRecallPrompts = true
    @AppStorage("noteStyle") private var noteStyleRaw: String = NoteStyle.detailed.rawValue
    @AppStorage("summaryLength") private var summaryLengthRaw: String = SummaryLength.comprehensive.rawValue
    @State private var geminiAPIKey: String = ""
    @State private var showingAPIKeyAlert = false

    private var noteStyle: NoteStyle {
        get { NoteStyle(rawValue: noteStyleRaw) ?? .detailed }
        set { noteStyleRaw = newValue.rawValue }
    }

    private var summaryLength: SummaryLength {
        get { SummaryLength(rawValue: summaryLengthRaw) ?? .comprehensive }
        set { summaryLengthRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Recording Section
                    SettingsSection(title: "Recording", icon: "waveform") {
                        VStack(spacing: 16) {
                            SettingRow(
                                icon: "mic.fill",
                                title: "Live Transcription",
                                description: "Transcribe during recording (uses more battery)"
                            ) {
                                Toggle("", isOn: $realtimeTranscription)
                                    .labelsHidden()
                            }

                            if !realtimeTranscription {
                                InfoBox(
                                    icon: "battery.100.bolt",
                                    message: "Battery saver enabled. Audio will be transcribed after you finish recording.",
                                    color: .green
                                )
                            } else {
                                InfoBox(
                                    icon: "waveform",
                                    message: "Live transcription enabled. Your audio will be transcribed as you record.",
                                    color: .blue
                                )
                            }
                        }
                    }

                    // AI Notes Section
                    SettingsSection(title: "AI Class Notes", icon: "brain") {
                        VStack(spacing: 16) {
                            SettingRow(
                                icon: "wand.and.stars",
                                title: "Auto-generate Notes",
                                description: "Create notes from transcripts automatically"
                            ) {
                                Toggle("", isOn: $autoGenerateClassNotes)
                                    .labelsHidden()
                            }

                            if autoGenerateClassNotes {
                                Divider()

                                // Recall Prompts Toggle
                                SettingRow(
                                    icon: "brain.head.profile",
                                    title: "Generate Recall Questions",
                                    description: "Create practice questions for post-lecture review"
                                ) {
                                    Toggle("", isOn: $generateRecallPrompts)
                                        .labelsHidden()
                                }

                                Divider()

                                // Note Style
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Note Style", systemImage: "doc.text")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)

                                    Picker("Note Style", selection: Binding(
                                        get: { noteStyle },
                                        set: { noteStyleRaw = $0.rawValue }
                                    )) {
                                        ForEach(NoteStyle.allCases) { style in
                                            Text(style.rawValue).tag(style)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(noteStyle.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                // Summary Length
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Detail Level", systemImage: "slider.horizontal.3")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)

                                    Picker("Summary Length", selection: Binding(
                                        get: { summaryLength },
                                        set: { summaryLengthRaw = $0.rawValue }
                                    )) {
                                        ForEach(SummaryLength.allCases) { length in
                                            Text(length.rawValue).tag(length)
                                        }
                                    }
                                    .pickerStyle(.segmented)

                                    Text(summaryLength.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                // API Key
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Gemini API Key", systemImage: "key.fill")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)

                                    HStack(spacing: 8) {
                                        SecureField("Enter your API key", text: $geminiAPIKey)
                                            .textFieldStyle(.roundedBorder)

                                        if !geminiAPIKey.isEmpty {
                                            Button("Save") {
                                                saveGeminiAPIKey()
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.regular)
                                        }
                                    }

                                    if geminiAPIKey.isEmpty && KeychainHelper.shared.getGeminiAPIKey() != nil {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .foregroundColor(.green)
                                            Text("API key saved securely")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Link(destination: URL(string: "https://ai.google.dev")!) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "link")
                                            Text("Get a free API key from Google AI")
                                            Image(systemName: "arrow.up.right")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }

                    // Class Folders Section
                    if !classViewModel.classes.isEmpty {
                        SettingsSection(title: "Class Folders", icon: "folder") {
                            VStack(spacing: 12) {
                                ForEach(classViewModel.classes) { classModel in
                                    ModernClassRow(classModel: classModel, classViewModel: classViewModel)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(SpongeTheme.coralPale.opacity(0.4))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .onAppear {
                loadGeminiAPIKey()
            }
            .alert("API Key Saved", isPresented: $showingAPIKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Gemini API key has been securely saved to the Keychain.")
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Helper Methods

    private func loadGeminiAPIKey() {
        if KeychainHelper.shared.getGeminiAPIKey() != nil {
            geminiAPIKey = ""
        }
    }

    private func saveGeminiAPIKey() {
        let trimmedKey = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            _ = KeychainHelper.shared.deleteGeminiAPIKey()
        } else {
            _ = KeychainHelper.shared.saveGeminiAPIKey(trimmedKey)
            showingAPIKeyAlert = true
        }
        geminiAPIKey = ""
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(SpongeTheme.coral)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
                    .padding(16)
            }
            .background(SpongeTheme.cream)
            .cornerRadius(SpongeTheme.cornerRadiusM)
            .overlay(
                RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                    .stroke(SpongeTheme.coral.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: SpongeTheme.shadowS, radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Setting Row

struct SettingRow<Accessory: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(SpongeTheme.coral.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(SpongeTheme.coral)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 12)

            accessory
        }
    }
}

// MARK: - Info Box

struct InfoBox: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)

            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Modern Class Row

struct ModernClassRow: View {
    let classModel: SDClass
    @ObservedObject var classViewModel: ClassViewModel
    @State private var showingClassEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "folder.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(classModel.name)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(classModel.saveDestination.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !classModel.isConfigurationValid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Button {
                    showingClassEditor = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }

            // Folder status
            FolderStatusBadge(
                type: "Local Folder",
                icon: "folder.fill",
                isConfigured: classModel.hasLocalFolder,
                name: classModel.resolveFolder()?.lastPathComponent ?? "Not configured"
            )
        }
        .padding(14)
        .background(Color.tertiaryBackground)
        .cornerRadius(10)
        .sheet(isPresented: $showingClassEditor) {
            ClassEditorView(classToEdit: classModel)
                .environmentObject(classViewModel)
        }
    }
}

// MARK: - Folder Status Badge

struct FolderStatusBadge: View {
    let type: String
    let icon: String
    let isConfigured: Bool
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isConfigured ? .blue : .secondary)
                .frame(width: 16)

            Text(type)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(name)
                .font(.caption)
                .foregroundColor(isConfigured ? .primary : .orange)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(name)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondaryBackground.opacity(0.5))
        .cornerRadius(6)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ClassViewModel())
}
