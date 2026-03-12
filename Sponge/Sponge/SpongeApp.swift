import SwiftUI
import SwiftData
import Sparkle

@main
struct SpongeApp: App {
    @StateObject private var classViewModel = ClassViewModel()

    // Sparkle updater — handles automatic update checks and user-initiated checks
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(classViewModel)
                .modelContainer(PersistenceService.shared.modelContainer)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)

        // "Check for Updates…" in the application menu
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
    }
}
