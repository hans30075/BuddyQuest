import SwiftUI
import BuddyQuestKit

// MARK: - App Screen State

enum AppScreen: Equatable {
    case profileSelection
    case mainMenu
    case game
}

// MARK: - Root Coordinator

/// Root navigation coordinator that manages the top-level app flow:
/// Profile Selection → Main Menu → Game
public struct AppCoordinator: View {
    @State private var currentScreen: AppScreen = .profileSelection
    @StateObject private var profileManager = ProfileManager.shared

    public init() {}

    public var body: some View {
        Group {
            switch currentScreen {
            case .profileSelection:
                ProfileSelectionView { profileId in
                    profileManager.setActive(id: profileId)
                    currentScreen = .mainMenu
                }
                .transition(.opacity)

            case .mainMenu:
                MainMenuView(
                    showGame: Binding(
                        get: { currentScreen == .game },
                        set: { if $0 { currentScreen = .game } }
                    ),
                    onSwitchProfile: {
                        currentScreen = .profileSelection
                    }
                )
                .transition(.opacity)

            case .game:
                GameContainerView(
                    gradeLevel: profileManager.activeProfile?.gradeLevel ?? .third,
                    onQuit: {
                        currentScreen = .mainMenu
                    },
                    onSwitchPlayer: {
                        currentScreen = .profileSelection
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentScreen)
    }
}
