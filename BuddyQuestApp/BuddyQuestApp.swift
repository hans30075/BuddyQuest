import SwiftUI
import BuddyQuestKit

@main
struct BuddyQuestApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1024, height: 768)
        .windowStyle(.hiddenTitleBar)
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                NotificationCenter.default.post(
                    name: .buddyQuestShouldSave,
                    object: nil
                )
            }
        }
    }
}
