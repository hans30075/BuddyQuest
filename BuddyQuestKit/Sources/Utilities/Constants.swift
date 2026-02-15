import Foundation
import CoreGraphics

// MARK: - Game Constants

public enum GameConstants {
    // MARK: Tile & Grid
    public static let tileSize: CGFloat = 48
    public static let tilesPerScreenWidth: Int = 20
    public static let tilesPerScreenHeight: Int = 15

    // MARK: Rendering
    public static let targetFPS: Double = 60
    public static let maxDeltaTime: TimeInterval = 1.0 / 30.0

    // MARK: Player
    public static let playerSpeed: CGFloat = 180
    public static let playerHitboxSize: CGSize = CGSize(width: 30, height: 20)
    public static let playerSpriteSize: CGSize = CGSize(width: 48, height: 48)
    public static let interactionRange: CGFloat = 52

    // MARK: Camera
    public static let cameraLerpSpeed: CGFloat = 5.0

    // MARK: Dialogue
    public static let typewriterCharsPerSecond: Double = 40
    public static let dialogueBoxHeight: CGFloat = 120

    // MARK: Challenge
    public static let defaultChallengeTimerSeconds: TimeInterval = 30
    public static let xpPerCorrectAnswer: Int = 10
    public static let xpPerWrongAnswer: Int = 2
    public static let xpBonusPerStreak: Int = 5
    public static let hintXPCost: Int = 3
    public static let challengeRoundSize: Int = 5
    public static let perQuestionFeedbackDuration: TimeInterval = 1.2
    public static let trueFalseTimerSeconds: TimeInterval = 20
    public static let fillBlankTimerSeconds: TimeInterval = 45
    public static let orderingTimerSeconds: TimeInterval = 45
    public static let matchingTimerSeconds: TimeInterval = 45

    // MARK: Progression
    public static let xpPerLevel: Int = 100
    public static let buddyUnlockLevels: [Int] = [1, 5, 10, 15]
    public static let maxActiveBuddies: Int = 2

    // MARK: Difficulty
    public static let difficultyWindowSize: Int = 10
    public static let difficultyIncreaseThreshold: Double = 0.8
    public static let difficultyDecreaseThreshold: Double = 0.4

    // MARK: AI
    public static let defaultMaxAICallsPerHour: Int = 30
    public static let aiResponseTimeout: TimeInterval = 15

    // MARK: Animation
    public static let walkAnimationFrameDuration: TimeInterval = 0.15
    public static let idleAnimationFrameDuration: TimeInterval = 0.5
    public static let fadeTransitionDuration: TimeInterval = 0.5

    // MARK: Buddy
    public static let buddyFollowDistance: CGFloat = 48
    public static let buddyFollowSpeed: CGFloat = 130
    public static let speechBubbleDuration: TimeInterval = 3.0

    // MARK: Bond System
    public static let bondGoodBuddyThreshold: Int = 50
    public static let bondGreatBuddyThreshold: Int = 150
    public static let bondBestBuddyThreshold: Int = 300

    public static let bondPointsPerCorrect: Int = 3
    public static let bondPointsPerWrong: Int = 1
    public static let bondPointsPerInteraction: Int = 2
    public static let bondPointsPerWalk: Int = 1
    public static let bondSubjectMatchBonus: Int = 1

    public static let bondInteractionCooldown: TimeInterval = 60   // seconds
    public static let bondWalkTileThreshold: Double = 200          // tiles

    public static let bondXPBonusFraction: Double = 0.10           // +10% XP at Great Buddy

    // MARK: Adaptive Question Bank
    public static let bankQuestionsPerSubject: Int = 35             // Target bank size per subject (~7 quizzes)
    public static let bankMinimumForQuiz: Int = 5                   // Min questions to draw from bank (else fallback)
    public static let bankReplenishBatchSize: Int = 10              // AI questions to generate per replenish cycle
    public static let bankMasteryThreshold: Int = 3                 // Correct answers before question is "mastered"
    public static let bankMasteryRemovalDelay: TimeInterval = 7 * 24 * 3600  // 7 days before removing mastered
    public static let bankRecentlyShownWindow: Int = 15             // Deprioritize last N shown questions
    public static let bankSeedStaticCount: Int = 20                 // Static questions for initial seed per subject
    public static let bankSeedAICount: Int = 15                     // AI questions for initial seed per subject
}

// MARK: - Color Palette

public enum GameColors {
    // Zone themes
    public static let hubPrimary = RGB(r: 100, g: 180, b: 255)       // Soft blue
    public static let wordForestPrimary = RGB(r: 80, g: 180, b: 100) // Forest green
    public static let numberPeaksPrimary = RGB(r: 100, g: 140, b: 220) // Mountain blue
    public static let scienceLabPrimary = RGB(r: 180, g: 100, b: 220)  // Lab purple
    public static let teamworkArenaPrimary = RGB(r: 255, g: 180, b: 80) // Warm orange

    // Buddy colors
    public static let novaColor = RGB(r: 0, g: 180, b: 180)     // Teal
    public static let lexieColor = RGB(r: 180, g: 100, b: 220)   // Purple
    public static let digitColor = RGB(r: 80, g: 140, b: 255)    // Blue
    public static let harmonyColor = RGB(r: 255, g: 140, b: 180) // Pink

    // UI
    public static let textPrimary = RGB(r: 50, g: 50, b: 60)
    public static let textLight = RGB(r: 255, g: 255, b: 255)
    public static let xpBarFill = RGB(r: 255, g: 200, b: 50)
    public static let healthFill = RGB(r: 255, g: 80, b: 80)
    public static let correctGreen = RGB(r: 80, g: 200, b: 80)
    public static let incorrectRed = RGB(r: 220, g: 80, b: 80)

    public struct RGB {
        public let r: UInt8
        public let g: UInt8
        public let b: UInt8

        public init(r: UInt8, g: UInt8, b: UInt8) {
            self.r = r
            self.g = g
            self.b = b
        }
    }
}

// MARK: - Z Positions (Layer Ordering)

public enum ZPositions {
    public static let floor: CGFloat = 0
    public static let walls: CGFloat = 5
    public static let decoration: CGFloat = 10
    public static let shadows: CGFloat = 15
    public static let entities: CGFloat = 20
    public static let player: CGFloat = 25
    public static let effects: CGFloat = 40
    public static let hud: CGFloat = 100
    public static let dialogue: CGFloat = 200
    public static let challenge: CGFloat = 300
    public static let transition: CGFloat = 400
}
