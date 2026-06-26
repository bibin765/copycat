import Foundation
import Sparkle

/// Thin wrapper around Sparkle's standard updater so SwiftUI can drive
/// "Check for Updates…" and observe whether a check is currently allowed.
@MainActor
final class UpdaterManager: ObservableObject {
    private let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    init() {
        // startingUpdater: true begins the scheduled background update checks.
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
