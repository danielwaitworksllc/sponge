import SwiftUI
import AVFoundation

struct OnboardingView: View {
    var onComplete: (_ showAddClass: Bool) -> Void

    @State private var currentStep: Int = 0
    @State private var apiKey: String = ""
    @State private var apiKeySaved: Bool = false
    @State private var micGranted: Bool = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            SpongePatternView(color: Color.white.opacity(0.08))

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.white : Color.white.opacity(0.35))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentStep)
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 28)

                // Step content
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep()
                    case 1:
                        MicPermissionStep(micGranted: $micGranted)
                    case 2:
                        APIKeyStep(apiKey: $apiKey, apiKeySaved: $apiKeySaved)
                    default:
                        ReadyStep()
                    }
                }
                .frame(maxWidth: 480)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)

                Spacer()

                // Navigation buttons
                VStack(spacing: 12) {
                    Button(action: advance) {
                        Text(continueLabel)
                            .frame(maxWidth: 300)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SpongeTheme.coral))

                    if currentStep == 2 {
                        Button("Skip for now") {
                            withAnimation(.easeInOut(duration: 0.3)) { currentStep = totalSteps - 1 }
                        }
                        .foregroundColor(Color.white.opacity(0.75))
                        .font(.subheadline)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 560, height: 500)
        .background(
            LinearGradient(
                colors: [SpongeTheme.coral, SpongeTheme.backgroundCoral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if let existing = KeychainHelper.shared.getGeminiAPIKey(), !existing.isEmpty {
                apiKeySaved = true
            }
            // Check if mic permission already granted
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    private var continueLabel: String {
        switch currentStep {
        case 1 where !micGranted: return "Grant Microphone Access"
        case totalSteps - 1: return "Let's go"
        default: return "Continue"
        }
    }

    private func advance() {
        if currentStep == 1 && !micGranted {
            // Request mic permission, then auto-advance when granted
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    micGranted = granted
                    withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
                }
            }
            return
        }

        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
        } else {
            onComplete(!apiKey.isEmpty || apiKeySaved)
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.white)
                .symbolEffect(.pulse)

            VStack(spacing: 10) {
                Text("Welcome to Sponge")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                Text("Record your lectures, get real-time transcripts, and let AI turn them into study notes.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "mic.fill", text: "Real-time transcription using Apple SpeechAnalyzer")
                FeatureRow(icon: "note.text", text: "AI-generated notes, summaries, and recall prompts")
                FeatureRow(icon: "lock.fill", text: "Transcription stays fully on-device")
            }
            .padding(.top, 8)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.9))
        }
    }
}

// MARK: - Step 2: Microphone Permission

private struct MicPermissionStep: View {
    @Binding var micGranted: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: micGranted ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 64))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: micGranted)

            VStack(spacing: 10) {
                Text(micGranted ? "Microphone Ready" : "Allow Microphone Access")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)

                Text(micGranted
                    ? "Sponge can hear your lectures. You're good to go."
                    : "Sponge needs your microphone to record and transcribe lectures. Tap the button below — macOS will ask you to confirm."
                )
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if !micGranted {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("A system dialog will appear. Choose \"OK\" to continue.")
                        .font(.caption)
                }
                .foregroundColor(Color.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Permission granted")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Step 3: Gemini API Key

private struct APIKeyStep: View {
    @Binding var apiKey: String
    @Binding var apiKeySaved: Bool

    @State private var saveError: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                Text("Enable AI Notes")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)

                Text("Paste a free Gemini API key to unlock AI study notes after each lecture. Takes 30 seconds to get one.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if apiKeySaved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("API key saved — AI notes are enabled")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
            } else {
                VStack(spacing: 10) {
                    // Step 1: Get key
                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                            Text("Step 1 — Get a free API key at aistudio.google.com")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(SpongeTheme.coral)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                    }

                    // Step 2: Paste key
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Step 2 — Paste it here")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.white.opacity(0.7))

                        TextField("AIza...", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .onChange(of: apiKey) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                                if trimmed.count > 20 {
                                    if KeychainHelper.shared.saveGeminiAPIKey(trimmed) {
                                        apiKeySaved = true
                                        saveError = nil
                                    }
                                }
                            }

                        if let error = saveError {
                            Text(error).font(.caption).foregroundColor(Color.yellow)
                        }
                    }
                }
                .frame(maxWidth: 380)
            }
        }
    }
}

// MARK: - Step 4: Ready

private struct ReadyStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.white)
                .symbolEffect(.bounce)

            VStack(spacing: 10) {
                Text("You're all set!")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                Text("Create your first class and start recording. Sponge will transcribe your lecture in real-time.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: "1", text: "Create a class (we'll prompt you next)")
                InstructionRow(number: "2", text: "Hit Record before your lecture starts")
                InstructionRow(number: "3", text: "Stop recording when done — notes generate automatically")
            }
            .padding(.top, 4)
        }
    }
}

private struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundColor(SpongeTheme.coral)
                .frame(width: 22, height: 22)
                .background(Color.white)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.9))
        }
    }
}
