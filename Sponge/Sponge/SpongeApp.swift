import SwiftUI
import SwiftData
import Sparkle
import TelemetryDeck

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

        var config = TelemetryDeck.Config(appID: "30F3FE98-DE23-4EB1-8391-34161BBEF509")
        config.analyticsDisabled = false
        TelemetryDeck.initialize(config: config)
        TelemetryDeck.signal("appLaunched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(updaterController: updaterController)
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
