import SwiftUI
import AppKit
import ScreenCaptureKit

struct ContentView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @StateObject private var recordingViewModel = RecordingViewModel()
    @State private var showingClassManagement = false
    @State private var showingAddClass = false
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Call detection: track last-shown call app so we don't spam the toast
    @State private var lastDetectedCallApp: String? = nil
    private let callCheckTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    if recordingViewModel.isRecording {
                        // When recording: full screen for recording view
                        RecordingView(recordingViewModel: recordingViewModel)
                            .frame(maxHeight: .infinity)
                            .background(SpongeTheme.cream)
                    } else {
                        // When not recording: show both recording view and recordings list
                        RecordingView(recordingViewModel: recordingViewModel)
                            .frame(minHeight: max(geometry.size.height * 0.35, 300), idealHeight: geometry.size.height * 0.42)
                            .layoutPriority(1)
                            .background(SpongeTheme.cream)

                        // Divider with coral accent
                        Rectangle()
                            .fill(SpongeTheme.coral.opacity(0.4))
                            .frame(height: 2)

                        // Recordings list
                        RecordingsListView()
                            .environmentObject(classViewModel)
                            .environmentObject(recordingViewModel)
                            .frame(minHeight: 200)
                            .background(SpongeTheme.coralPale.opacity(0.3))
                    }
                }
            }
            .background(SpongeTheme.coralPale.opacity(0.4))
            .navigationTitle("Sponge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingClassManagement = true
                        } label: {
                            Label("Manage Classes", systemImage: "folder.badge.gearshape")
                        }

                        Divider()

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingClassManagement) {
                ClassManagementView()
                    .environmentObject(classViewModel)
            }
            .sheet(isPresented: $showingAddClass) {
                ClassEditorView(classToEdit: nil)
                    .environmentObject(classViewModel)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(classViewModel)
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView { showAddClass in
                    hasCompletedOnboarding = true
                    showingOnboarding = false
                    if showAddClass || classViewModel.classes.isEmpty {
                        showingAddClass = true
                    }
                }
            }
            .onAppear {
                if !hasCompletedOnboarding {
                    showingOnboarding = true
                } else if classViewModel.classes.isEmpty {
                    showingAddClass = true
                }
                // If a class is scheduled right now, surface a banner so the user knows
                if let banner = classViewModel.suggestedClassBanner {
                    recordingViewModel.toastMessage = ToastMessage(
                        message: banner,
                        icon: "calendar.badge.clock",
                        type: .info
                    )
                    classViewModel.suggestedClassBanner = nil
                }
                // Request notification permission on first launch
                NotificationService.shared.requestAuthorization()
                // Reschedule in case classes already exist
                NotificationService.shared.rescheduleAll(for: classViewModel.classes)
            }
            .onReceive(callCheckTimer) { _ in
                guard !recordingViewModel.isRecording else { return }
                checkForActiveCalls()
            }
            .toast($recordingViewModel.toastMessage)
        }
    }

    // MARK: - Call Detection

    /// Checks for active video call applications (Zoom, Teams, Google Meet).
    /// Shows a one-time toast suggestion to switch to Meeting mode.
    private func checkForActiveCalls() {
        let runningApps = NSWorkspace.shared.runningApplications

        let zoomBundles = ["us.zoom.xos", "com.zoom.us"]
        let teamsBundles = ["com.microsoft.teams", "com.microsoft.teams2"]

        if runningApps.contains(where: { zoomBundles.contains($0.bundleIdentifier ?? "") }) {
            showCallDetectionToast(for: "Zoom")
            return
        }
        if runningApps.contains(where: { teamsBundles.contains($0.bundleIdentifier ?? "") }) {
            showCallDetectionToast(for: "Teams")
            return
        }

        // Google Meet is browser-based — check window titles via SCShareableContent (best-effort)
        Task {
            if let app = await detectGoogleMeet() {
                await MainActor.run { showCallDetectionToast(for: app) }
            }
        }
    }

    private func showCallDetectionToast(for appName: String) {
        // Only show once per detected app to avoid repeated toasts
        guard lastDetectedCallApp != appName else { return }
        lastDetectedCallApp = appName
        recordingViewModel.toastMessage = ToastMessage(
            message: "\(appName) detected — switch to Meeting mode to record",
            icon: "video.fill",
            type: .info
        )
        // Clear after 60s so it can re-trigger if the same app is still running
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if self.lastDetectedCallApp == appName {
                self.lastDetectedCallApp = nil
            }
        }
    }

    /// Checks SCShareableContent window titles for Google Meet browser tabs.
    /// Requires Screen Recording permission — fails silently if not granted.
    private func detectGoogleMeet() async -> String? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            return nil
        }
        let browserBundles = ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox",
                              "com.microsoft.edgemac", "com.brave.Browser"]
        let meetKeywords = ["Google Meet", "meet.google.com", "Meet -"]

        for window in content.windows {
            guard let bundleId = window.owningApplication?.bundleIdentifier,
                  browserBundles.contains(bundleId),
                  let title = window.title else { continue }
            if meetKeywords.contains(where: { title.contains($0) }) {
                return "Google Meet"
            }
        }
        return nil
    }
}

// MARK: - Color Extensions

extension Color {
    static var primaryBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }

    static var secondaryBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }

    static var tertiaryBackground: Color {
        Color(NSColor.textBackgroundColor)
    }
}

#Preview {
    ContentView()
        .environmentObject(ClassViewModel())
}
