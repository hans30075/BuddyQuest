import SwiftUI
import SpriteKit
import Combine
import BuddyQuestKit

/// Wraps the SpriteKit GameEngine scene in SwiftUI
public struct GameContainerView: View {
    @StateObject private var viewModel: GameContainerViewModel

    let onQuit: () -> Void
    let onSwitchPlayer: () -> Void

    public init(
        gradeLevel: GradeLevel = .third,
        onQuit: @escaping () -> Void = {},
        onSwitchPlayer: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: GameContainerViewModel(gradeLevel: gradeLevel))
        self.onQuit = onQuit
        self.onSwitchPlayer = onSwitchPlayer
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // SpriteKit game scene
                SpriteView(
                    scene: viewModel.gameScene(size: geometry.size),
                    options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
                )
                .ignoresSafeArea()

                // iOS virtual controls overlay
                #if os(iOS)
                VirtualControlsOverlay(inputManager: viewModel.inputManager)
                #endif

                // Dim overlay while paused (profile sheet is shown as .sheet)
                if viewModel.isPaused {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
        .sheet(isPresented: $viewModel.showProfile, onDismiss: {
            viewModel.resume()
        }) {
            if let scene = viewModel.currentScene {
                ProfileSheet(
                    scene: scene,
                    isInGame: true,
                    onSwitchPlayer: {
                        viewModel.showProfile = false
                        viewModel.quit()
                        onSwitchPlayer()
                    },
                    onQuit: {
                        viewModel.showProfile = false
                        viewModel.quit()
                        onQuit()
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showBuddySelect, onDismiss: {
            // Resume game when buddy select is closed (profile is already dismissed)
            viewModel.resume()
        }) {
            if let scene = viewModel.currentScene {
                BuddySelectSheet(
                    bondSystem: scene.bondSystem,
                    onSelect: { buddyType in
                        scene.switchBuddy(to: buddyType)
                    }
                )
            }
        }
        .onAppear {
            // Check for first-time buddy selection after scene initializes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.checkFirstTimeBuddySelect()
            }
        }
        .onChange(of: viewModel.isPaused) { _, paused in
            if paused && !viewModel.showProfile && !viewModel.showBuddySelect {
                // Game just paused (via badge click or ESC) — show profile sheet
                // But not if buddy select was requested (buddy badge click)
                if let scene = viewModel.currentScene, scene.buddySelectRequested {
                    scene.buddySelectRequested = false
                    viewModel.showBuddySelect = true
                } else {
                    viewModel.showProfile = true
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class GameContainerViewModel: ObservableObject {
    @Published var isPaused = false
    @Published var showProfile = false
    @Published var showBuddySelect = false

    private var scene: GameEngine?
    private let gradeLevel: GradeLevel
    private var stateObservation: AnyCancellable?

    init(gradeLevel: GradeLevel = .third) {
        self.gradeLevel = gradeLevel
    }

    var inputManager: InputManager {
        scene?.inputManager ?? InputManager()
    }

    /// Expose the scene for the profile sheet to read stats
    var currentScene: GameEngine? { scene }

    func gameScene(size: CGSize) -> GameEngine {
        if let existing = scene {
            return existing
        }
        let newScene = GameEngine.createScene(size: size, gradeLevel: gradeLevel)
        scene = newScene

        // Observe game state changes to sync pause state to SwiftUI
        stateObservation = newScene.stateManager.$currentState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.isPaused = (state == .paused)
            }

        return newScene
    }

    func resume() {
        scene?.stateManager.transition(to: .playing)
        isPaused = false
        showProfile = false
    }

    func quit() {
        isPaused = false
    }

    /// Show buddy selection sheet if this is a first-time launch
    func checkFirstTimeBuddySelect() {
        if let scene = scene, scene.needsInitialBuddySelection {
            scene.needsInitialBuddySelection = false
            showBuddySelect = true
        }
    }
}

// MARK: - Game Menu Button Style

struct GameMenuButtonStyle: ButtonStyle {
    let foreground: Color
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(foreground.opacity(0.2), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Unified Profile Sheet
//
// Used from both the main menu ("Playing as …" banner) and the in-game
// pause screen.  When `scene` is provided, Level & XP and Subject
// Performance sections are shown.  When `isInGame` is true, the top-right
// button says "Resume" and Quit / Switch Player actions appear at the bottom.

struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileManager = ProfileManager.shared
    @State private var showEditSheet = false

    /// Optional game scene — when provided, game stats (Level & XP, Subject Performance) are shown.
    let scene: GameEngine?

    /// Whether this sheet is presented from within the game.
    /// Controls the top-right button label ("Resume" vs "Done") and shows game actions.
    let isInGame: Bool

    /// Callback to switch to a different player profile.
    var onSwitchPlayer: (() -> Void)?

    /// Callback to quit the game and return to the main menu (in-game only).
    var onQuit: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("My Profile")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Button(isInGame ? "Resume" : "Done") { dismiss() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .buttonStyle(.borderedProminent)
                    .tint(isInGame ? .green : .accentColor)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // ── Profile Card ──
                    if let profile = profileManager.activeProfile {
                        let rgb = profile.color.rgb
                        let profileColor = Color(red: rgb.r, green: rgb.g, blue: rgb.b)

                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(profileColor)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: profileColor.opacity(0.5), radius: 8)
                                Text(profile.initial)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Text(profile.name)
                                .font(.system(size: 22, weight: .bold, design: .rounded))

                            HStack(spacing: 8) {
                                Text(profile.gradeLevel.displayName)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.secondary)

                                Button {
                                    showEditSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil.circle.fill")
                                        Text("Edit Profile")
                                    }
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                        .padding(.top, 8)

                        // ── Info Section (always shown) ──
                        VStack(spacing: 12) {
                            profileInfoRow(
                                icon: "calendar",
                                label: "Playing Since",
                                value: profile.createdDate.formatted(date: .abbreviated, time: .omitted)
                            )
                            profileInfoRow(
                                icon: "graduationcap.fill",
                                label: "Grade Level",
                                value: profile.gradeLevel.displayName
                            )
                        }
                        .padding(.top, 8)
                    }

                    // ── Level & XP (in-game only) ──
                    if let scene = scene {
                        VStack(spacing: 8) {
                            sectionHeader("Level & XP")

                            HStack(spacing: 20) {
                                statBox(
                                    label: "Level",
                                    value: "\(scene.player.level)",
                                    icon: "star.fill",
                                    color: .yellow
                                )
                                statBox(
                                    label: "Total XP",
                                    value: "\(scene.player.totalXP)",
                                    icon: "bolt.fill",
                                    color: .orange
                                )
                                statBox(
                                    label: "Next Level",
                                    value: "\(GameConstants.xpPerLevel - scene.player.xpForCurrentLevel) XP",
                                    icon: "arrow.up.circle.fill",
                                    color: .green
                                )
                            }
                        }

                        // ── Subject Performance (in-game only) ──
                        VStack(spacing: 8) {
                            sectionHeader("Subject Performance")

                            ForEach(BuddyQuestKit.Subject.allCases, id: \.rawValue) { subject in
                                subjectRow(subject, scene: scene)
                            }
                        }
                    }

                    // ── Tip (always shown) ──
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                        Text("Moving up a grade? Tap \"Edit Profile\" to update your grade level. Questions will adjust to match!")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.yellow.opacity(0.08))
                    )

                    // ── Actions ──
                    Divider()
                        .padding(.horizontal, -20)

                    VStack(spacing: 8) {
                        // Switch Player (always available)
                        Button {
                            onSwitchPlayer?()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("Switch Player")
                            }
                        }
                        .buttonStyle(GameMenuButtonStyle(
                            foreground: Color(red: 0.3, green: 0.5, blue: 0.8),
                            background: Color(red: 0.3, green: 0.5, blue: 0.8).opacity(0.1)
                        ))

                        // Quit to Menu (in-game only)
                        if isInGame {
                            Button {
                                onQuit?()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Quit to Menu")
                                }
                            }
                            .buttonStyle(GameMenuButtonStyle(
                                foreground: .secondary,
                                background: Color.primary.opacity(0.05)
                            ))
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 400, minHeight: isInGame ? 560 : 440)
        .sheet(isPresented: $showEditSheet) {
            if let profile = profileManager.activeProfile {
                ProfileCreateEditView(existingProfile: profile)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func profileInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)
            Spacer()
        }
    }

    @ViewBuilder
    private func statBox(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
    }

    @ViewBuilder
    private func subjectRow(_ subject: BuddyQuestKit.Subject, scene: GameEngine) -> some View {
        let completed = scene.progressionSystem.subjectCompletedCount[subject] ?? 0
        let correct = scene.progressionSystem.subjectCorrectCount[subject] ?? 0
        let accuracy = completed > 0 ? Double(correct) / Double(completed) : 0
        let difficulty = scene.progressionSystem.subjectDifficulty[subject] ?? .easy

        HStack(spacing: 12) {
            // Subject color dot
            Circle()
                .fill(subjectColor(subject))
                .frame(width: 10, height: 10)

            // Subject name
            Text(subject.rawValue)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(width: 100, alignment: .leading)

            // Accuracy bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(subjectColor(subject))
                        .frame(width: geo.size.width * CGFloat(accuracy), height: 8)
                }
            }
            .frame(height: 8)

            // Accuracy %
            Text(completed > 0 ? "\(Int(accuracy * 100))%" : "—")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)

            // Difficulty badge
            Text(difficultyName(difficulty))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(subjectColor(subject).opacity(0.7)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func subjectColor(_ subject: BuddyQuestKit.Subject) -> Color {
        switch subject {
        case .languageArts: return Color(red: 0.7, green: 0.4, blue: 0.86)
        case .math: return Color(red: 0.3, green: 0.55, blue: 1.0)
        case .science: return Color(red: 0, green: 0.7, blue: 0.7)
        case .social: return Color(red: 1.0, green: 0.55, blue: 0.7)
        }
    }

    private func difficultyName(_ level: DifficultyLevel) -> String {
        switch level {
        case .beginner: return "BEGINNER"
        case .easy: return "EASY"
        case .medium: return "MEDIUM"
        case .hard: return "HARD"
        case .advanced: return "ADVANCED"
        }
    }
}

// MARK: - Virtual Controls (iOS)

#if os(iOS)
struct VirtualControlsOverlay: View {
    let inputManager: InputManager

    var body: some View {
        VStack {
            Spacer()
            HStack {
                // Virtual joystick area (left)
                VirtualJoystick(inputManager: inputManager)
                    .frame(width: 120, height: 120)
                    .padding(.leading, 20)
                    .padding(.bottom, 20)

                Spacer()

                // Action buttons (right)
                VStack(spacing: 12) {
                    ActionButton(label: "E", action: .interact, inputManager: inputManager)
                    ActionButton(label: "I", action: .inventory, inputManager: inputManager)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

struct VirtualJoystick: View {
    let inputManager: InputManager
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 120, height: 120)

            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 50, height: 50)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let maxDist: CGFloat = 35
                            let x = max(-maxDist, min(maxDist, value.translation.width))
                            let y = max(-maxDist, min(maxDist, value.translation.height))
                            dragOffset = CGSize(width: x, height: y)

                            let direction = CGPoint(
                                x: x / maxDist,
                                y: -y / maxDist  // Flip Y for SpriteKit
                            )
                            inputManager.setVirtualJoystick(direction: direction)
                        }
                        .onEnded { _ in
                            dragOffset = .zero
                            inputManager.setVirtualJoystick(direction: .zero)
                        }
                )
        }
    }
}

struct ActionButton: View {
    let label: String
    let action: InputAction
    let inputManager: InputManager

    var body: some View {
        Button {
            inputManager.pressVirtualButton(action)
        } label: {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.white.opacity(0.3)))
        }
    }
}
#endif
