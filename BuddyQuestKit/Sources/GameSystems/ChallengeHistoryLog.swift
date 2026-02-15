import Foundation

// MARK: - Challenge History Entry

/// A single logged question attempt, stored for parent progress report trend analysis.
public struct ChallengeHistoryEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let subject: Subject
    public let skillDomain: SkillDomain
    public let difficulty: DifficultyLevel
    public let gradeLevel: GradeLevel
    public let isCorrect: Bool
    public let questionText: String    // Truncated for storage efficiency
    public let questionType: QuestionType?  // nil for legacy entries (defaults to .multipleChoice)

    public init(
        timestamp: Date = Date(),
        subject: Subject,
        skillDomain: SkillDomain,
        difficulty: DifficultyLevel,
        gradeLevel: GradeLevel,
        isCorrect: Bool,
        questionText: String,
        questionType: QuestionType? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.subject = subject
        self.skillDomain = skillDomain
        self.difficulty = difficulty
        self.gradeLevel = gradeLevel
        self.isCorrect = isCorrect
        self.questionText = String(questionText.prefix(120))
        self.questionType = questionType
    }
}

// MARK: - Challenge History Store

/// Persistent store wrapping the history array with a version number.
struct ChallengeHistoryStore: Codable {
    var entries: [ChallengeHistoryEntry]
    var version: Int

    init() {
        self.entries = []
        self.version = 1
    }
}

// MARK: - Challenge History Log

/// Manages per-profile challenge history for parent progress reports.
/// Stores data in a separate JSON file per profile: buddyquest_history_{profileId}.json
/// This is deliberately separate from SaveData to avoid backward compatibility issues.
public final class ChallengeHistoryLog {

    public static let shared = ChallengeHistoryLog()

    private var store: ChallengeHistoryStore = ChallengeHistoryStore()
    private var activeProfileId: UUID?

    private init() {}

    // MARK: - Profile Lifecycle

    /// Set the active profile for all subsequent log operations.
    public func setActiveProfile(_ id: UUID) {
        // Save current profile's data if switching
        if activeProfileId != nil && activeProfileId != id {
            save()
        }
        activeProfileId = id
        load()
    }

    /// Delete history for a profile (called when profile is deleted).
    public func deleteHistory(for profileId: UUID) {
        let url = documentsDir.appendingPathComponent(
            "buddyquest_history_\(profileId.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        // If this was the active profile, clear in-memory store
        if activeProfileId == profileId {
            store = ChallengeHistoryStore()
        }
    }

    // MARK: - Logging

    /// Log a batch of question results from a single challenge round.
    /// Called from GameEngine after challenge completion.
    /// Each question is classified into a SkillDomain using keyword heuristics.
    public func logChallengeRound(
        subject: Subject,
        questions: [MultipleChoiceQuestion],
        results: [Bool]
    ) {
        let now = Date()
        for (i, question) in questions.enumerated() {
            guard i < results.count else { break }
            let domain = StandardsMapping.classifyQuestion(
                questionText: question.question,
                subject: subject
            )
            let entry = ChallengeHistoryEntry(
                timestamp: now,
                subject: subject,
                skillDomain: domain,
                difficulty: question.difficulty,
                gradeLevel: question.gradeLevel,
                isCorrect: results[i],
                questionText: question.question
            )
            store.entries.append(entry)
        }
        save()
    }

    /// Log a batch of question results from a mixed-type challenge round.
    /// Uses universal Question type instead of MultipleChoiceQuestion.
    public func logChallengeRound(
        subject: Subject,
        questions: [Question],
        results: [Bool]
    ) {
        let now = Date()
        for (i, question) in questions.enumerated() {
            guard i < results.count else { break }
            let domain = StandardsMapping.classifyQuestion(
                questionText: question.questionText,
                subject: subject
            )
            let entry = ChallengeHistoryEntry(
                timestamp: now,
                subject: subject,
                skillDomain: domain,
                difficulty: question.difficulty,
                gradeLevel: question.gradeLevel,
                isCorrect: results[i],
                questionText: question.questionText,
                questionType: question.questionType
            )
            store.entries.append(entry)
        }
        save()
    }

    // MARK: - Queries

    /// All entries for a given subject, optionally filtered by date range.
    public func entries(
        for subject: Subject,
        since: Date? = nil
    ) -> [ChallengeHistoryEntry] {
        store.entries.filter { entry in
            entry.subject == subject &&
            (since == nil || entry.timestamp >= since!)
        }
    }

    /// All entries across all subjects.
    public var allEntries: [ChallengeHistoryEntry] {
        store.entries
    }

    /// Total number of entries logged.
    public var totalEntries: Int {
        store.entries.count
    }

    /// Entries grouped by skill domain for a given subject.
    public func entriesByDomain(for subject: Subject) -> [SkillDomain: [ChallengeHistoryEntry]] {
        var grouped: [SkillDomain: [ChallengeHistoryEntry]] = [:]
        for entry in store.entries where entry.subject == subject {
            grouped[entry.skillDomain, default: []].append(entry)
        }
        return grouped
    }

    // MARK: - Persistence

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var fileURL: URL {
        guard let profileId = activeProfileId else {
            return documentsDir.appendingPathComponent("buddyquest_history.json")
        }
        return documentsDir.appendingPathComponent(
            "buddyquest_history_\(profileId.uuidString).json")
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(store)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[ChallengeHistoryLog] Save failed: \(error)")
        }
    }

    private func load() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            store = ChallengeHistoryStore()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            store = try decoder.decode(ChallengeHistoryStore.self, from: data)
        } catch {
            print("[ChallengeHistoryLog] Load failed: \(error)")
            store = ChallengeHistoryStore()
        }
    }

    /// Load history for a specific profile without changing the active profile.
    /// Used by the parent dashboard to read any child's history.
    public func loadEntries(for profileId: UUID) -> [ChallengeHistoryEntry] {
        let url = documentsDir.appendingPathComponent(
            "buddyquest_history_\(profileId.uuidString).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode(ChallengeHistoryStore.self, from: data)
            return loaded.entries
        } catch {
            print("[ChallengeHistoryLog] Load for profile \(profileId) failed: \(error)")
            return []
        }
    }
}
