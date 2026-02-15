import Foundation

// MARK: - Save Data

/// All persistent game state, serialized to JSON
public struct SaveData: Codable {
    // Player
    public var playerLevel: Int
    public var playerTotalXP: Int
    public var playerHealth: Int

    // Location (resume where player left off)
    public var currentZoneId: String
    public var currentRoomId: String

    // Progression per subject (keyed by Subject.rawValue)
    public var subjectDifficulty: [String: Int]      // Subject.rawValue -> DifficultyLevel.rawValue
    public var subjectCompletedCount: [String: Int]
    public var subjectCorrectCount: [String: Int]

    // Game flags (door locks, quest markers)
    public var gameFlags: [String]

    // Buddy
    public var activeBuddyType: String?              // BuddyType.rawValue
    public var unlockedBuddies: [String]             // [BuddyType.rawValue]
    public var buddyBonds: [String: BuddyBondData]?  // BuddyType.rawValue -> bond data

    // Quest system
    public var questData: QuestSaveData?

    // Metadata
    public var saveVersion: Int
    public var lastSaveDate: Date
}

// MARK: - Notification

public extension Notification.Name {
    /// Posted when the app should save (e.g. backgrounding, quitting)
    static let buddyQuestShouldSave = Notification.Name("buddyQuestShouldSave")
}

// MARK: - Save System

/// Lightweight persistence using Codable + FileManager.
/// Saves player progress to a JSON file in the app's documents directory.
public final class SaveSystem {

    public static let shared = SaveSystem()

    private static let legacySaveFileName = "buddyquest_save.json"
    private static let currentSaveVersion = 1

    /// The active profile whose save file we read/write
    private var activeProfileId: UUID?

    private init() {}

    // MARK: - Profile Selection

    /// Set the active profile for all subsequent save/load operations.
    public func setActiveProfile(_ id: UUID) {
        activeProfileId = id
    }

    // MARK: - Save File Location

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var saveFileURL: URL {
        guard let profileId = activeProfileId else {
            return documentsDir.appendingPathComponent(Self.legacySaveFileName)
        }
        return documentsDir.appendingPathComponent("buddyquest_save_\(profileId.uuidString).json")
    }

    // MARK: - Legacy Migration

    /// True if the old single-file save exists (pre-profile system)
    public var hasLegacySave: Bool {
        FileManager.default.fileExists(
            atPath: documentsDir.appendingPathComponent(Self.legacySaveFileName).path
        )
    }

    /// Migrate the old single save file to a profile-specific file
    public func migrateLegacySave(to profileId: UUID) {
        let legacyURL = documentsDir.appendingPathComponent(Self.legacySaveFileName)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        let newURL = documentsDir.appendingPathComponent("buddyquest_save_\(profileId.uuidString).json")
        do {
            try FileManager.default.moveItem(at: legacyURL, to: newURL)
            print("[SaveSystem] Migrated legacy save to profile \(profileId)")
        } catch {
            print("[SaveSystem] Legacy migration failed: \(error)")
        }
    }

    /// Delete the save file for a specific profile (called on profile deletion)
    public func deleteSave(for profileId: UUID) {
        let url = documentsDir.appendingPathComponent("buddyquest_save_\(profileId.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        print("[SaveSystem] Deleted save for profile \(profileId)")
    }

    // MARK: - Save

    public func save(
        player: PlayerCharacter,
        worldManager: WorldManager,
        progressionSystem: ProgressionSystem,
        activeBuddyType: BuddyType?,
        unlockedBuddies: [BuddyType],
        bondSystem: BuddyBondSystem? = nil,
        questSystem: QuestSystem? = nil
    ) {
        let data = SaveData(
            playerLevel: player.level,
            playerTotalXP: player.totalXP,
            playerHealth: player.health,
            currentZoneId: worldManager.currentZoneId ?? "buddy_base",
            currentRoomId: worldManager.currentRoomId ?? "hub_main",
            subjectDifficulty: encodeSubjectDifficulty(progressionSystem),
            subjectCompletedCount: encodeSubjectCount(progressionSystem.subjectCompletedCount),
            subjectCorrectCount: encodeSubjectCount(progressionSystem.subjectCorrectCount),
            gameFlags: Array(worldManager.gameFlags),
            activeBuddyType: activeBuddyType?.rawValue,
            unlockedBuddies: unlockedBuddies.map(\.rawValue),
            buddyBonds: bondSystem?.exportBonds(),
            questData: questSystem?.exportState(),
            saveVersion: Self.currentSaveVersion,
            lastSaveDate: Date()
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: saveFileURL, options: .atomic)
            print("[SaveSystem] Saved successfully to \(saveFileURL.lastPathComponent)")
        } catch {
            print("[SaveSystem] Save failed: \(error)")
        }
    }

    // MARK: - Load

    public func load() -> SaveData? {
        guard FileManager.default.fileExists(atPath: saveFileURL.path) else {
            print("[SaveSystem] No save file found")
            return nil
        }
        do {
            let jsonData = try Data(contentsOf: saveFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let saveData = try decoder.decode(SaveData.self, from: jsonData)
            print("[SaveSystem] Loaded save (version \(saveData.saveVersion), level \(saveData.playerLevel), XP \(saveData.playerTotalXP))")
            return saveData
        } catch {
            print("[SaveSystem] Load failed: \(error)")
            return nil
        }
    }

    /// Load save data for a specific profile without changing the active profile.
    /// Used by the parent dashboard to read any child's save.
    public func loadSaveData(for profileId: UUID) -> SaveData? {
        let url = documentsDir.appendingPathComponent("buddyquest_save_\(profileId.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SaveData.self, from: jsonData)
        } catch {
            print("[SaveSystem] Load for profile \(profileId) failed: \(error)")
            return nil
        }
    }

    // MARK: - Apply Loaded Data

    public func apply(
        _ saveData: SaveData,
        to player: PlayerCharacter,
        worldManager: WorldManager,
        progressionSystem: ProgressionSystem,
        questSystem: QuestSystem? = nil
    ) {
        // Restore player stats
        player.totalXP = saveData.playerTotalXP
        player.level = saveData.playerLevel
        player.health = saveData.playerHealth

        // Restore game flags
        worldManager.gameFlags = Set(saveData.gameFlags)

        // Restore progression difficulty + counts
        for subject in Subject.allCases {
            let key = subject.rawValue
            if let rawDiff = saveData.subjectDifficulty[key],
               let diff = DifficultyLevel(rawValue: rawDiff) {
                progressionSystem.setDifficulty(diff, for: subject)
            }
            if let completed = saveData.subjectCompletedCount[key] {
                progressionSystem.setCompletedCount(completed, for: subject)
            }
            if let correct = saveData.subjectCorrectCount[key] {
                progressionSystem.setCorrectCount(correct, for: subject)
            }
        }

        // Restore quest state
        if let questData = saveData.questData {
            questSystem?.importState(questData)
        }

        print("[SaveSystem] Applied save data — Level \(saveData.playerLevel), Zone: \(saveData.currentZoneId)/\(saveData.currentRoomId)")
    }

    // MARK: - Delete / Check

    public func deleteSave() {
        try? FileManager.default.removeItem(at: saveFileURL)
        print("[SaveSystem] Save deleted")
    }

    public var hasSave: Bool {
        FileManager.default.fileExists(atPath: saveFileURL.path)
    }

    // MARK: - Lightweight Buddy Accessors (for menus, before game loads)

    /// Read just the active buddy type from the save file without loading everything.
    public func loadActiveBuddyType() -> BuddyType? {
        guard let saveData = load() else { return nil }
        guard let rawValue = saveData.activeBuddyType else { return nil }
        return BuddyType(rawValue: rawValue)
    }

    /// Update just the active buddy type in the save file.
    /// Loads existing save, patches the buddy, and re-saves.
    public func saveActiveBuddyType(_ buddyType: BuddyType) {
        guard FileManager.default.fileExists(atPath: saveFileURL.path) else {
            // No save file yet — will be set when game first saves
            return
        }
        do {
            let jsonData = try Data(contentsOf: saveFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var saveData = try decoder.decode(SaveData.self, from: jsonData)
            saveData.activeBuddyType = buddyType.rawValue
            saveData.lastSaveDate = Date()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let updatedData = try encoder.encode(saveData)
            try updatedData.write(to: saveFileURL, options: .atomic)
            print("[SaveSystem] Updated active buddy to \(buddyType.displayName)")
        } catch {
            print("[SaveSystem] Failed to update active buddy: \(error)")
        }
    }

    // MARK: - Encoding Helpers

    private func encodeSubjectDifficulty(_ ps: ProgressionSystem) -> [String: Int] {
        var result: [String: Int] = [:]
        for subject in Subject.allCases {
            result[subject.rawValue] = ps.subjectDifficulty[subject]?.rawValue ?? DifficultyLevel.easy.rawValue
        }
        return result
    }

    private func encodeSubjectCount(_ dict: [Subject: Int]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (subject, count) in dict {
            result[subject.rawValue] = count
        }
        return result
    }
}
