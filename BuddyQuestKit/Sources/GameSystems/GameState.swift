import Foundation

// MARK: - Core Enums

public enum Subject: String, CaseIterable, Codable, Sendable {
    case languageArts = "Language Arts"
    case math = "Math"
    case science = "Science"
    case social = "Social Skills"
}

public enum DifficultyLevel: Int, Codable, Comparable, Sendable {
    case beginner = 1
    case easy = 2
    case medium = 3
    case hard = 4
    case advanced = 5

    public static func < (lhs: DifficultyLevel, rhs: DifficultyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var next: DifficultyLevel {
        DifficultyLevel(rawValue: min(rawValue + 1, 5)) ?? .advanced
    }

    public var previous: DifficultyLevel {
        DifficultyLevel(rawValue: max(rawValue - 1, 1)) ?? .beginner
    }
}

public enum GradeLevel: Int, Codable, CaseIterable, Sendable {
    case kindergarten = 0
    case first = 1, second = 2, third = 3
    case fourth = 4, fifth = 5, sixth = 6
    case seventh = 7, eighth = 8

    public var displayName: String {
        switch self {
        case .kindergarten: return "Kindergarten"
        default: return "Grade \(rawValue)"
        }
    }
}

public enum BuddyType: String, CaseIterable, Codable, Sendable {
    case nova
    case lexie
    case digit
    case harmony

    public var displayName: String {
        switch self {
        case .nova: return "Nova"
        case .lexie: return "Lexie"
        case .digit: return "Digit"
        case .harmony: return "Harmony"
        }
    }

    public var subject: Subject {
        switch self {
        case .nova: return .science
        case .lexie: return .languageArts
        case .digit: return .math
        case .harmony: return .social
        }
    }
}

public enum Direction: String, Codable, Sendable {
    case up, down, left, right

    public var dx: CGFloat {
        switch self {
        case .left: return -1
        case .right: return 1
        default: return 0
        }
    }

    public var dy: CGFloat {
        switch self {
        case .up: return 1
        case .down: return -1
        default: return 0
        }
    }
}

// AIProvider enum moved to AI/AIServiceProtocol.swift

// MARK: - Game State Machine

public enum GameState: Equatable {
    case title
    case playing
    case dialogue
    case challenge
    case inventory
    case paused
    case transition
    case buddySelect
    case questLog
    case settings

    public static func == (lhs: GameState, rhs: GameState) -> Bool {
        switch (lhs, rhs) {
        case (.title, .title),
             (.playing, .playing),
             (.dialogue, .dialogue),
             (.challenge, .challenge),
             (.inventory, .inventory),
             (.paused, .paused),
             (.transition, .transition),
             (.buddySelect, .buddySelect),
             (.questLog, .questLog),
             (.settings, .settings):
            return true
        default:
            return false
        }
    }
}

/// Manages game state transitions and notifies observers
public final class GameStateManager: ObservableObject {
    @Published public private(set) var currentState: GameState = .title
    @Published public private(set) var previousState: GameState = .title

    public init() {}

    public func transition(to newState: GameState) {
        guard newState != currentState else { return }
        previousState = currentState
        currentState = newState
    }

    public func returnToPrevious() {
        let temp = currentState
        currentState = previousState
        previousState = temp
    }

    public var isPlaying: Bool { currentState == .playing }
    public var isInOverlay: Bool {
        switch currentState {
        case .dialogue, .challenge, .inventory, .paused, .buddySelect, .questLog, .settings:
            return true
        default:
            return false
        }
    }
}
