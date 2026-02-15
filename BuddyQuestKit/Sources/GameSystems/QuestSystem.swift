import Foundation

// MARK: - Quest Objective Types

/// The kinds of goals a quest can require
public enum QuestObjectiveType: Codable {
    /// Complete N challenges in a specific subject
    case completeChallenges(subject: Subject, count: Int)
    /// Visit a specific room
    case visitRoom(roomId: String)
    /// Talk to a specific NPC (by NPC id)
    case talkToNPC(npcId: String)
    /// Reach a certain difficulty level in a subject
    case reachDifficulty(subject: Subject, level: DifficultyLevel)
    /// Reach a player level
    case reachLevel(level: Int)
}

// MARK: - Quest Progress

/// Persistent progress toward a single objective
public struct QuestObjectiveProgress: Codable {
    public var currentCount: Int = 0
    public var isComplete: Bool = false

    public init(currentCount: Int = 0, isComplete: Bool = false) {
        self.currentCount = currentCount
        self.isComplete = isComplete
    }
}

/// The state of a quest in the player's journal
public enum QuestStatus: String, Codable {
    case available   // Can be accepted (prerequisites met)
    case active      // Player has accepted, working on it
    case completed   // All objectives done, rewards claimed
}

// MARK: - Quest Reward

/// Reward for completing a quest
public struct QuestReward: Codable {
    public var xpBonus: Int
    public var bondPoints: Int
    public var unlocksFlag: String?  // Added to WorldManager.gameFlags

    public init(xpBonus: Int = 0, bondPoints: Int = 0, unlocksFlag: String? = nil) {
        self.xpBonus = xpBonus
        self.bondPoints = bondPoints
        self.unlocksFlag = unlocksFlag
    }
}

// MARK: - Quest Definition

/// Static definition of a quest (immutable data, like DialogueData entries)
public struct QuestDefinition {
    public let id: String
    public let name: String
    public let description: String
    public let giverNPCId: String          // NPC that gives this quest
    public let turnInNPCId: String         // NPC to talk to when complete (often same)
    public let objectives: [QuestObjectiveType]
    public let reward: QuestReward
    public let prerequisiteQuestIds: [String]  // Must be completed first
    public let prerequisiteLevel: Int          // Player level required

    public init(
        id: String,
        name: String,
        description: String,
        giverNPCId: String,
        turnInNPCId: String,
        objectives: [QuestObjectiveType],
        reward: QuestReward,
        prerequisiteQuestIds: [String] = [],
        prerequisiteLevel: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.giverNPCId = giverNPCId
        self.turnInNPCId = turnInNPCId
        self.objectives = objectives
        self.reward = reward
        self.prerequisiteQuestIds = prerequisiteQuestIds
        self.prerequisiteLevel = prerequisiteLevel
    }
}

// MARK: - Quest Save Data

/// Codable save data for quest state
public struct QuestSaveData: Codable {
    public var questStatuses: [String: QuestStatus]
    public var questProgress: [String: [QuestObjectiveProgress]]

    public init(
        questStatuses: [String: QuestStatus] = [:],
        questProgress: [String: [QuestObjectiveProgress]] = [:]
    ) {
        self.questStatuses = questStatuses
        self.questProgress = questProgress
    }
}

// MARK: - Quest System

/// Manages quest state, objective tracking, and reward distribution.
/// Owned by GameEngine, persisted through SaveSystem.
public final class QuestSystem {

    // MARK: - State (persisted)

    /// Status of each quest by quest ID
    public private(set) var questStatuses: [String: QuestStatus] = [:]

    /// Progress per objective per quest: questId -> [objectiveIndex -> progress]
    public private(set) var questProgress: [String: [QuestObjectiveProgress]] = [:]

    public init() {}

    // MARK: - Quest Availability

    /// Get all quests that should show as available for the player
    public func availableQuests(playerLevel: Int, flags: Set<String>) -> [QuestDefinition] {
        QuestData.allQuests.filter { def in
            let status = questStatuses[def.id]
            // Only show quests not yet started
            guard status == nil || status == .available else { return false }
            // Check player level
            guard playerLevel >= def.prerequisiteLevel else { return false }
            // Check prerequisite quests
            for prereq in def.prerequisiteQuestIds {
                guard questStatuses[prereq] == .completed else { return false }
            }
            return true
        }
    }

    /// Quests that a specific NPC can give (available + that NPC is the giver)
    public func questsForNPC(_ npcId: String, playerLevel: Int, flags: Set<String>) -> [QuestDefinition] {
        availableQuests(playerLevel: playerLevel, flags: flags)
            .filter { $0.giverNPCId == npcId }
    }

    /// Active quests that this NPC can complete (turnInNPCId matches, all objectives done)
    public func completableQuestsForNPC(_ npcId: String) -> [QuestDefinition] {
        QuestData.allQuests.filter { def in
            guard questStatuses[def.id] == .active else { return false }
            guard def.turnInNPCId == npcId else { return false }
            return isAllObjectivesComplete(questId: def.id)
        }
    }

    // MARK: - Quest Lifecycle

    /// Accept a quest (transitions from available to active)
    public func acceptQuest(_ questId: String) {
        guard let def = QuestData.quest(forId: questId) else { return }
        questStatuses[questId] = .active
        questProgress[questId] = Array(
            repeating: QuestObjectiveProgress(),
            count: def.objectives.count
        )
        print("[QuestSystem] Accepted quest: \(def.name)")
    }

    /// Complete a quest and return the reward
    @discardableResult
    public func completeQuest(_ questId: String) -> QuestReward? {
        guard questStatuses[questId] == .active else { return nil }
        guard isAllObjectivesComplete(questId: questId) else { return nil }
        guard let def = QuestData.quest(forId: questId) else { return nil }
        questStatuses[questId] = .completed
        print("[QuestSystem] Completed quest: \(def.name)")
        return def.reward
    }

    // MARK: - Objective Progress Tracking

    /// Record a challenge completion. Checks all active quests for matching objectives.
    public func recordChallengeComplete(subject: Subject) {
        for (questId, status) in questStatuses where status == .active {
            guard let def = QuestData.quest(forId: questId) else { continue }
            for (i, obj) in def.objectives.enumerated() {
                if case .completeChallenges(let s, let count) = obj, s == subject {
                    updateProgress(questId: questId, objectiveIndex: i, targetCount: count)
                }
            }
        }
    }

    /// Record visiting a room
    public func recordRoomVisit(roomId: String) {
        for (questId, status) in questStatuses where status == .active {
            guard let def = QuestData.quest(forId: questId) else { continue }
            for (i, obj) in def.objectives.enumerated() {
                if case .visitRoom(let r) = obj, r == roomId {
                    markObjectiveComplete(questId: questId, objectiveIndex: i)
                }
            }
        }
    }

    /// Record talking to an NPC
    public func recordNPCTalk(npcId: String) {
        for (questId, status) in questStatuses where status == .active {
            guard let def = QuestData.quest(forId: questId) else { continue }
            for (i, obj) in def.objectives.enumerated() {
                if case .talkToNPC(let n) = obj, n == npcId {
                    markObjectiveComplete(questId: questId, objectiveIndex: i)
                }
            }
        }
    }

    /// Check difficulty-based objectives
    public func recordDifficultyReached(subject: Subject, level: DifficultyLevel) {
        for (questId, status) in questStatuses where status == .active {
            guard let def = QuestData.quest(forId: questId) else { continue }
            for (i, obj) in def.objectives.enumerated() {
                if case .reachDifficulty(let s, let l) = obj, s == subject, level >= l {
                    markObjectiveComplete(questId: questId, objectiveIndex: i)
                }
            }
        }
    }

    /// Check level-based objectives
    public func recordLevelReached(_ level: Int) {
        for (questId, status) in questStatuses where status == .active {
            guard let def = QuestData.quest(forId: questId) else { continue }
            for (i, obj) in def.objectives.enumerated() {
                if case .reachLevel(let l) = obj, level >= l {
                    markObjectiveComplete(questId: questId, objectiveIndex: i)
                }
            }
        }
    }

    // MARK: - Query Helpers

    /// Whether an NPC has a quest to give (yellow !)
    public func npcHasQuestToGive(_ npcId: String, playerLevel: Int, flags: Set<String>) -> Bool {
        !questsForNPC(npcId, playerLevel: playerLevel, flags: flags).isEmpty
    }

    /// Whether an NPC has a quest to turn in (green ?)
    public func npcHasQuestToComplete(_ npcId: String) -> Bool {
        !completableQuestsForNPC(npcId).isEmpty
    }

    /// Get active quest count
    public var activeQuestCount: Int {
        questStatuses.values.filter { $0 == .active }.count
    }

    /// Get all active quest definitions
    public var activeQuests: [QuestDefinition] {
        QuestData.allQuests.filter { questStatuses[$0.id] == .active }
    }

    /// Get all completed quest definitions
    public var completedQuests: [QuestDefinition] {
        QuestData.allQuests.filter { questStatuses[$0.id] == .completed }
    }

    /// Get progress description for a quest
    public func progressDescription(for questId: String) -> String {
        guard let def = QuestData.quest(forId: questId),
              let progress = questProgress[questId] else { return "" }
        var parts: [String] = []
        for (i, obj) in def.objectives.enumerated() {
            let p = i < progress.count ? progress[i] : QuestObjectiveProgress()
            switch obj {
            case .completeChallenges(let subject, let count):
                parts.append("\(subject.rawValue): \(p.currentCount)/\(count)")
            case .visitRoom:
                parts.append(p.isComplete ? "Explored ✓" : "Explore area")
            case .talkToNPC:
                parts.append(p.isComplete ? "Talked ✓" : "Talk to NPC")
            case .reachDifficulty(let subject, let level):
                parts.append(p.isComplete ? "\(subject.rawValue) Lv\(level.rawValue) ✓" : "\(subject.rawValue) Lv\(level.rawValue)")
            case .reachLevel(let level):
                parts.append(p.isComplete ? "Level \(level) ✓" : "Reach Level \(level)")
            }
        }
        return parts.joined(separator: " | ")
    }

    // MARK: - Persistence

    public func exportState() -> QuestSaveData {
        QuestSaveData(
            questStatuses: questStatuses,
            questProgress: questProgress
        )
    }

    public func importState(_ data: QuestSaveData) {
        questStatuses = data.questStatuses
        questProgress = data.questProgress
    }

    // MARK: - Private Helpers

    private func updateProgress(questId: String, objectiveIndex: Int, targetCount: Int) {
        guard var progress = questProgress[questId],
              objectiveIndex < progress.count else { return }
        guard !progress[objectiveIndex].isComplete else { return }
        progress[objectiveIndex].currentCount += 1
        if progress[objectiveIndex].currentCount >= targetCount {
            progress[objectiveIndex].isComplete = true
            print("[QuestSystem] Objective \(objectiveIndex) complete for quest \(questId)")
        }
        questProgress[questId] = progress
    }

    private func markObjectiveComplete(questId: String, objectiveIndex: Int) {
        guard var progress = questProgress[questId],
              objectiveIndex < progress.count else { return }
        guard !progress[objectiveIndex].isComplete else { return }
        progress[objectiveIndex].currentCount = 1
        progress[objectiveIndex].isComplete = true
        questProgress[questId] = progress
        print("[QuestSystem] Objective \(objectiveIndex) complete for quest \(questId)")
    }

    private func isAllObjectivesComplete(questId: String) -> Bool {
        guard let progress = questProgress[questId] else { return false }
        return progress.allSatisfy { $0.isComplete }
    }
}
