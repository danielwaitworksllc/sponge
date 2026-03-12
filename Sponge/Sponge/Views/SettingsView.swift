import SwiftUI
import AppKit
import Sparkle

struct SettingsView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    var updaterController: SPUStandardUpdaterController?

    var body: some View {
        NavigationStack {
            TabView {
                GeneralTab()
                    .tabItem { Label("General", systemImage: "gearshape") }

                AINotesTab()
                    .tabItem { Label("AI Notes", systemImage: "brain") }

                NotificationsTab(classes: classViewModel.classes)
                    .tabItem { Label("Notifications", systemImage: "bell") }

                AboutTab(updaterController: updaterController)
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
            .padding(20)
            .background(SpongeTheme.coralPale.opacity(0.4))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @AppStorage("realtimeTranscription") private var realtimeTranscription = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
            }
        }
    }
}

// MARK: - AI Notes Tab

private struct AINotesTab: View {
    @AppStorage("autoGenerateClassNotes") private var autoGenerateClassNotes = false
    @AppStorage("generateRecallPrompts") private var generateRecallPrompts = true
    @AppStorage("noteStyle") private var noteStyleRaw: String = NoteStyle.detailed.rawValue
    @AppStorage("summaryLength") private var summaryLengthRaw: String = SummaryLength.comprehensive.rawValue
    @State private var geminiAPIKey: String = ""
    @State private var showingAPIKeyAlert = false

    private var noteStyle: NoteStyle {
        NoteStyle(rawValue: noteStyleRaw) ?? .detailed
    }

    private var summaryLength: SummaryLength {
        SummaryLength(rawValue: summaryLengthRaw) ?? .comprehensive
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // API Key Section (always visible — most important for setup)
                SettingsSection(title: "Gemini API Key", icon: "key.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        if KeychainHelper.shared.getGeminiAPIKey() != nil && geminiAPIKey.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("API key saved securely")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Replace") {
                                    geminiAPIKey = " " // trigger edit mode
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            HStack(spacing: 8) {
                                SecureField("Paste your API key", text: $geminiAPIKey)
                                    .textFieldStyle(.roundedBorder)

                                if !geminiAPIKey.trimmingCharacters(in: .whitespaces).isEmpty {
                                    Button("Save") {
                                        saveAPIKey()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                }
                            }
                        }

                        Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                Text("Get a free API key from Google AI Studio")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }

                // Note Generation Section
                SettingsSection(title: "Note Generation", icon: "brain") {
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

                            SettingRow(
                                icon: "brain.head.profile",
                                title: "Generate Recall Questions",
                                description: "Create practice questions for post-lecture review"
                            ) {
                                Toggle("", isOn: $generateRecallPrompts)
                                    .labelsHidden()
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Note Style", systemImage: "doc.text")
                                    .font(.subheadline.weight(.medium))

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

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Detail Level", systemImage: "slider.horizontal.3")
                                    .font(.subheadline.weight(.medium))

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
                        }
                    }
                }
            }
        }
        .alert("API Key Saved", isPresented: $showingAPIKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your Gemini API key has been securely saved to the Keychain.")
        }
    }

    private func saveAPIKey() {
        let trimmed = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            _ = KeychainHelper.shared.deleteGeminiAPIKey()
        } else {
            _ = KeychainHelper.shared.saveGeminiAPIKey(trimmed)
            showingAPIKeyAlert = true
        }
        geminiAPIKey = ""
    }
}

// MARK: - Notifications Tab

private struct NotificationsTab: View {
    let classes: [SDClass]

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("reminderLeadMinutes") private var reminderLeadMinutes = 5

    private let leadTimeOptions = [5, 10, 15, 30]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(title: "Class Reminders", icon: "bell.fill") {
                    VStack(spacing: 16) {
                        SettingRow(
                            icon: "bell.badge",
                            title: "Reminder Notifications",
                            description: "Get notified before each scheduled class"
                        ) {
                            Toggle("", isOn: $notificationsEnabled)
                                .labelsHidden()
                                .onChange(of: notificationsEnabled) { _, enabled in
                                    if enabled {
                                        NotificationService.shared.requestAuthorization()
                                        NotificationService.shared.rescheduleAll(for: classes)
                                    } else {
                                        NotificationService.shared.removeAll()
                                    }
                                }
                        }

                        if notificationsEnabled {
                            Divider()

                            HStack {
                                Label("Remind me", systemImage: "clock")
                                    .font(.subheadline.weight(.medium))

                                Spacer()

                                Picker("", selection: $reminderLeadMinutes) {
                                    ForEach(leadTimeOptions, id: \.self) { minutes in
                                        Text("\(minutes) min before").tag(minutes)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 160)
                                .onChange(of: reminderLeadMinutes) { _, _ in
                                    NotificationService.shared.rescheduleAll(for: classes)
                                }
                            }

                            let scheduledCount = classes.filter(\.hasSchedule).count
                            InfoBox(
                                icon: "calendar.badge.clock",
                                message: scheduledCount > 0
                                    ? "\(scheduledCount) class\(scheduledCount == 1 ? "" : "es") with scheduled reminders. Edit schedules in Manage Classes."
                                    : "No classes have schedules yet. Add a schedule in Manage Classes to get reminders.",
                                color: scheduledCount > 0 ? .blue : .orange
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    var updaterController: SPUStandardUpdaterController?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (build \(build))"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon + name
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(SpongeTheme.coral)

                Text("Sponge")
                    .font(.title.weight(.bold))

                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Actions
            VStack(spacing: 10) {
                if let updater = updaterController {
                    Button {
                        updater.checkForUpdates(nil)
                    } label: {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: 220)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SpongeTheme.coral))
                }

                Link(destination: URL(string: "https://github.com/danielwaitworksllc/classrecordingmacapp")!) {
                    Label("View on GitHub", systemImage: "link")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
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

#Preview {
    SettingsView()
        .environmentObject(ClassViewModel())
}
