import SwiftUI
import AppKit
import Sparkle

struct ContentView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @StateObject private var recordingViewModel = RecordingViewModel()
    @State private var showingClassManagement = false
    @State private var showingAddClass = false
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showFullRecordingView = false
    @State private var recordingsCollapsed = false

    var updaterController: SPUStandardUpdaterController?


    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    if recordingViewModel.isRecording && !showFullRecordingView {
                        // Compact recording bar — user can browse recordings below
                        CompactRecordingBar(
                            recordingViewModel: recordingViewModel,
                            onExpand: { withAnimation(.easeInOut(duration: 0.25)) { showFullRecordingView = true } }
                        )
                    } else if recordingViewModel.isRecording && showFullRecordingView {
                        // Full recording view with transcript + notes
                        HStack(spacing: 0) {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) { showFullRecordingView = false }
                            } label: {
                                Label("Browse Recordings", systemImage: "list.bullet")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(SpongeTheme.coral)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 20)
                            .padding(.top, 10)
                        }

                        RecordingView(recordingViewModel: recordingViewModel)
                            .frame(maxHeight: .infinity)
                    } else {
                        // Idle: show recording controls
                        RecordingView(recordingViewModel: recordingViewModel)
                            .frame(height: recordingsCollapsed
                                ? geometry.size.height - 45
                                : geometry.size.height * 0.4)
                    }

                    // Recordings list — hidden when full recording view is active
                    if !(recordingViewModel.isRecording && showFullRecordingView) {
                        Rectangle()
                            .fill(SpongeTheme.divider)
                            .frame(height: 1)

                        RecordingsListView(isCollapsed: $recordingsCollapsed)
                            .environmentObject(classViewModel)
                            .environmentObject(recordingViewModel)
                            .frame(height: recordingsCollapsed
                                ? 45
                                : geometry.size.height * 0.6)
                    }
                }
            }
            .onChange(of: recordingViewModel.isRecording) { _, isRecording in
                // When recording starts, default to compact mode so user can browse
                if isRecording {
                    showFullRecordingView = true
                }
            }
            .background(SpongeTheme.cream.ignoresSafeArea())
            .navigationTitle("Sponge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                    .help("Settings")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingClassManagement = true } label: {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.title3)
                    }
                    .help("Manage Classes")
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
                SettingsView(updaterController: updaterController)
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
            .toast($recordingViewModel.toastMessage)
        }
    }

}


#Preview {
    ContentView(updaterController: nil)
        .environmentObject(ClassViewModel())
}
