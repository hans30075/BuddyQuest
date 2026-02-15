import Foundation

// MARK: - Report Data Models

/// Trend direction for accuracy over time
public enum AccuracyTrend: String, Sendable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
    case insufficientData = "Not enough data"

    /// SF Symbol name for display
    public var symbolName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .insufficientData: return "minus"
        }
    }
}

/// Mastery level for a standards domain
public enum MasteryLevel: String, Sendable {
    case mastered = "Mastered"           // >= 80% accuracy, 10+ questions
    case inProgress = "In Progress"      // 50-79% accuracy, or < 10 questions with some activity
    case needsWork = "Needs Practice"    // < 50% accuracy with attempts
    case notStarted = "Not Started"      // No questions attempted

    /// SF Symbol name for display
    public var symbolName: String {
        switch self {
        case .mastered: return "checkmark.circle.fill"
        case .inProgress: return "circle.dotted"
        case .needsWork: return "exclamationmark.triangle.fill"
        case .notStarted: return "minus.circle"
        }
    }
}

/// Per-domain detail within a subject
public struct DomainReport: Identifiable, Sendable {
    public let id: String
    public let domain: SkillDomain
    public let questionsAttempted: Int
    public let questionsCorrect: Int
    public let masteryLevel: MasteryLevel
    public let trend: AccuracyTrend

    public var accuracy: Double {
        guard questionsAttempted > 0 else { return 0 }
        return Double(questionsCorrect) / Double(questionsAttempted)
    }

    public init(
        domain: SkillDomain,
        questionsAttempted: Int,
        questionsCorrect: Int,
        masteryLevel: MasteryLevel,
        trend: AccuracyTrend
    ) {
        self.id = domain.rawValue
        self.domain = domain
        self.questionsAttempted = questionsAttempted
        self.questionsCorrect = questionsCorrect
        self.masteryLevel = masteryLevel
        self.trend = trend
    }
}

/// Per-subject breakdown
public struct SubjectReport: Identifiable, Sendable {
    public let id: String
    public let subject: Subject
    public let totalAttempted: Int
    public let totalCorrect: Int
    public let currentDifficulty: DifficultyLevel
    public let workingGradeLevel: GradeLevel
    public let trend: AccuracyTrend
    public let domains: [DomainReport]
    public let recommendations: [String]

    public var accuracy: Double {
        guard totalAttempted > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempted)
    }
}

/// The full progress report
public struct ProgressReport: Sendable {
    public let profileName: String
    public let enrolledGrade: GradeLevel
    public let generatedDate: Date
    public let playingSince: Date
    public let playerLevel: Int
    public let totalXP: Int
    public let totalQuestionsAnswered: Int
    public let overallAccuracy: Double
    public let subjectReports: [SubjectReport]
    public let topRecommendations: [String]
}

// MARK: - Generator

/// Produces a structured ProgressReport from raw data.
/// Compares the child's performance against California grade-level standards.
public final class ProgressReportGenerator {

    /// Generate a full progress report for a given profile.
    public static func generate(
        profile: PlayerProfile,
        saveData: SaveData?,
        history: [ChallengeHistoryEntry]
    ) -> ProgressReport {
        let enrolledGrade = profile.gradeLevel

        // Overall stats from SaveData (lifetime, includes pre-history data)
        let playerLevel = saveData?.playerLevel ?? 1
        let totalXP = saveData?.playerTotalXP ?? 0
        let lifetimeTotal = saveData.map { data in
            data.subjectCompletedCount.values.reduce(0, +)
        } ?? 0
        let lifetimeCorrect = saveData.map { data in
            data.subjectCorrectCount.values.reduce(0, +)
        } ?? 0
        let totalAnswered = max(lifetimeTotal, history.count)
        let overallAcc: Double = totalAnswered > 0
            ? Double(max(lifetimeCorrect, history.filter(\.isCorrect).count)) / Double(totalAnswered)
            : 0

        // Build per-subject reports
        var subjectReports: [SubjectReport] = []
        var allRecommendations: [(priority: Int, text: String)] = []

        for subject in Subject.allCases {
            let subjectHistory = history.filter { $0.subject == subject }
            let expectedDomains = StandardsMapping.expectedDomains(
                subject: subject, gradeLevel: enrolledGrade)

            // Current difficulty from save
            let diffRaw = saveData?.subjectDifficulty[subject.rawValue] ?? DifficultyLevel.easy.rawValue
            let currentDifficulty = DifficultyLevel(rawValue: diffRaw) ?? .easy

            // Working grade level inferred from difficulty
            let workingGrade = inferWorkingGrade(
                enrolled: enrolledGrade, difficulty: currentDifficulty)

            // Subject-level totals from history
            let subTotal = subjectHistory.count
            let subCorrect = subjectHistory.filter(\.isCorrect).count

            // If no history, fall back to save data
            let displayTotal: Int
            let displayCorrect: Int
            if subTotal > 0 {
                displayTotal = subTotal
                displayCorrect = subCorrect
            } else {
                displayTotal = saveData?.subjectCompletedCount[subject.rawValue] ?? 0
                displayCorrect = saveData?.subjectCorrectCount[subject.rawValue] ?? 0
            }

            // Subject-level trend
            let subjectTrend = computeTrend(entries: subjectHistory)

            // Per-domain breakdown
            var domainReports: [DomainReport] = []
            var subjectRecs: [String] = []

            // Group history by domain
            var domainEntries: [SkillDomain: [ChallengeHistoryEntry]] = [:]
            for entry in subjectHistory {
                domainEntries[entry.skillDomain, default: []].append(entry)
            }

            for domain in expectedDomains {
                let entries = domainEntries[domain] ?? []
                let attempted = entries.count
                let correct = entries.filter(\.isCorrect).count
                let mastery = determineMastery(attempted: attempted, correct: correct)
                let trend = computeTrend(entries: entries)

                domainReports.append(DomainReport(
                    domain: domain,
                    questionsAttempted: attempted,
                    questionsCorrect: correct,
                    masteryLevel: mastery,
                    trend: trend
                ))

                // Generate recommendations
                switch mastery {
                case .needsWork:
                    let rec = "Practice more \(domain.shortName) questions in \(subject.rawValue) to build confidence."
                    subjectRecs.append(rec)
                    allRecommendations.append((priority: 1, text: rec))
                case .notStarted:
                    let rec = "Explore \(domain.shortName) in \(subject.rawValue) — this area hasn't been started yet!"
                    subjectRecs.append(rec)
                    allRecommendations.append((priority: 2, text: rec))
                case .inProgress:
                    if trend == .declining {
                        let rec = "Keep practicing \(domain.shortName) — recent scores are dipping."
                        subjectRecs.append(rec)
                        allRecommendations.append((priority: 3, text: rec))
                    }
                case .mastered:
                    break // Positive — no action needed
                }
            }

            // Grade level recommendation
            if workingGrade.rawValue < enrolledGrade.rawValue && displayTotal > 10 {
                let rec = "\(subject.rawValue): Working below \(enrolledGrade.displayName) level — more practice at current level will help build up."
                subjectRecs.append(rec)
                allRecommendations.append((priority: 1, text: rec))
            } else if workingGrade.rawValue > enrolledGrade.rawValue {
                let rec = "Great job in \(subject.rawValue)! Working above \(enrolledGrade.displayName) expectations."
                subjectRecs.append(rec)
                allRecommendations.append((priority: 10, text: rec))
            }

            subjectReports.append(SubjectReport(
                id: subject.rawValue,
                subject: subject,
                totalAttempted: displayTotal,
                totalCorrect: displayCorrect,
                currentDifficulty: currentDifficulty,
                workingGradeLevel: workingGrade,
                trend: subjectTrend,
                domains: domainReports,
                recommendations: subjectRecs
            ))
        }

        // Top 3 recommendations (sorted by priority: 1 = most urgent)
        let topRecs = allRecommendations
            .sorted { $0.priority < $1.priority }
            .prefix(3)
            .map(\.text)

        return ProgressReport(
            profileName: profile.name,
            enrolledGrade: enrolledGrade,
            generatedDate: Date(),
            playingSince: profile.createdDate,
            playerLevel: playerLevel,
            totalXP: totalXP,
            totalQuestionsAnswered: totalAnswered,
            overallAccuracy: overallAcc,
            subjectReports: subjectReports,
            topRecommendations: Array(topRecs)
        )
    }

    // MARK: - Private Helpers

    /// Infer working grade level from enrolled grade and current difficulty.
    private static func inferWorkingGrade(
        enrolled: GradeLevel,
        difficulty: DifficultyLevel
    ) -> GradeLevel {
        let base = enrolled.rawValue
        let offset: Int
        switch difficulty {
        case .beginner: offset = -1
        case .easy: offset = 0
        case .medium: offset = 0
        case .hard: offset = 1
        case .advanced: offset = 1
        }
        let clamped = max(0, min(8, base + offset))
        return GradeLevel(rawValue: clamped) ?? enrolled
    }

    /// Compute accuracy trend by comparing first half vs second half of entries.
    /// Requires at least 10 entries for a meaningful signal.
    private static func computeTrend(
        entries: [ChallengeHistoryEntry]
    ) -> AccuracyTrend {
        guard entries.count >= 10 else { return .insufficientData }
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        let midpoint = sorted.count / 2
        let firstHalf = sorted[..<midpoint]
        let secondHalf = sorted[midpoint...]
        let firstAcc = Double(firstHalf.filter(\.isCorrect).count)
                     / Double(firstHalf.count)
        let secondAcc = Double(secondHalf.filter(\.isCorrect).count)
                      / Double(secondHalf.count)
        let delta = secondAcc - firstAcc
        if delta > 0.05 { return .improving }
        if delta < -0.05 { return .declining }
        return .stable
    }

    /// Determine mastery level from accuracy and question count.
    private static func determineMastery(
        attempted: Int,
        correct: Int
    ) -> MasteryLevel {
        guard attempted > 0 else { return .notStarted }
        let accuracy = Double(correct) / Double(attempted)
        if attempted >= 10 && accuracy >= 0.8 { return .mastered }
        if accuracy < 0.5 { return .needsWork }
        return .inProgress
    }
}
