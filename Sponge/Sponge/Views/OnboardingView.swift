import SwiftUI

struct OnboardingView: View {
    var onComplete: (_ showAddClass: Bool) -> Void

    @State private var currentStep: Int = 0
    @State private var apiKey: String = ""
    @State private var apiKeySaved: Bool = false

    private let totalSteps = 3

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
                        Text(currentStep == totalSteps - 1 ? "Let's go" : "Continue")
                            .frame(maxWidth: 300)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SpongeTheme.coral))

                    if currentStep == 1 {
                        Button("Skip for now") {
                            withAnimation { currentStep = totalSteps - 1 }
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
        .frame(width: 560, height: 480)
        .background(
            LinearGradient(
                colors: [SpongeTheme.coral, SpongeTheme.backgroundCoral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            // Pre-fill if key already exists
            if let existing = KeychainHelper.shared.getGeminiAPIKey(), !existing.isEmpty {
                apiKeySaved = true
            }
        }
    }

    private func advance() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
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

                Text("Record your lectures, get real-time transcripts, and let AI turn them into study notes — all on-device.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "mic.fill", text: "High-quality transcription via Apple SpeechAnalyzer")
                FeatureRow(icon: "note.text", text: "AI-generated notes, summaries, and recall prompts")
                FeatureRow(icon: "lock.fill", text: "Everything stays private on your Mac")
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

// MARK: - Step 2: Gemini API Key

private struct APIKeyStep: View {
    @Binding var apiKey: String
    @Binding var apiKeySaved: Bool

    @State private var isSaving: Bool = false
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

                Text("Add a free Gemini API key to unlock AI-generated study notes, summaries, and recall prompts after each lecture.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 8) {
                if apiKeySaved {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("API key saved securely")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(10)
                } else {
                    SecureField("Paste your API key here", text: $apiKey)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    if let error = saveError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color.yellow)
                    }

                    HStack(spacing: 16) {
                        Button("Save Key") {
                            saveKey()
                        }
                        .buttonStyle(SecondaryButtonStyle(color: .white))
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                        Link("Get a free key →", destination: URL(string: "https://ai.google.dev")!)
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                }
            }
            .frame(maxWidth: 380)
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        saveError = nil
        let success = KeychainHelper.shared.saveGeminiAPIKey(trimmed)
        isSaving = false
        if success {
            apiKeySaved = true
            apiKey = ""
        } else {
            saveError = "Could not save key. Please try again."
        }
    }
}

// MARK: - Step 3: Ready

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
                InstructionRow(number: "3", text: "Grant microphone access when asked")
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
