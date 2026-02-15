import Foundation

/// Manages per-player adaptive question banks.
/// Questions are pre-loaded and drawn locally during NPC interactions (no AI wait).
/// After each quiz, AI runs in the background to update the bank — removing mastered
/// questions and adding appropriately challenging new ones.
public final class AdaptiveQuestionBankManager {

    public static let shared = AdaptiveQuestionBankManager()

    private var bankData: QuestionBankData = QuestionBankData()
    private var activeProfileId: UUID?
    private let questionGenerator = QuestionGenerator()

    /// Track recently shown question IDs per subject to avoid repeats across quizzes.
    private var recentlyShownIds: [Subject: [UUID]] = [:]

    /// Prevent concurrent replenishment tasks for the same subject.
    private var isReplenishing: [Subject: Bool] = [:]

    private init() {}

    // MARK: - Profile Management

    /// Set the active player profile and load their question bank from disk.
    public func setActiveProfile(_ id: UUID) {
        activeProfileId = id
        loadBank()
    }

    // MARK: - File Paths

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var bankFileURL: URL {
        guard let profileId = activeProfileId else {
            return documentsDir.appendingPathComponent("buddyquest_questionbank.json")
        }
        return documentsDir.appendingPathComponent("buddyquest_questionbank_\(profileId.uuidString).json")
    }

    // MARK: - Persistence

    /// Save the question bank to disk (atomic write).
    public func saveBank() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(bankData)
            try data.write(to: bankFileURL, options: .atomic)
            print("[QuestionBank] Saved bank to \(bankFileURL.lastPathComponent) (\(totalQuestionCount) total)")
        } catch {
            print("[QuestionBank] Save failed: \(error)")
        }
    }

    private func loadBank() {
        guard FileManager.default.fileExists(atPath: bankFileURL.path) else {
            bankData = QuestionBankData()
            recentlyShownIds = [:]
            print("[QuestionBank] No bank file found, starting fresh")
            return
        }
        do {
            let data = try Data(contentsOf: bankFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            bankData = try decoder.decode(QuestionBankData.self, from: data)
            recentlyShownIds = [:]
            print("[QuestionBank] Loaded bank (\(totalQuestionCount) total questions)")
        } catch {
            print("[QuestionBank] Load failed: \(error), starting fresh")
            bankData = QuestionBankData()
            recentlyShownIds = [:]
        }
    }

    /// Delete the question bank file for a given profile (called on profile deletion).
    public func deleteBank(for profileId: UUID) {
        let url = documentsDir.appendingPathComponent("buddyquest_questionbank_\(profileId.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        print("[QuestionBank] Deleted bank for profile \(profileId)")
    }

    private var totalQuestionCount: Int {
        bankData.banks.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Draw Questions for Quiz

    /// Draw questions from the bank for a quiz round.
    /// Returns nil if the bank doesn't have enough questions (caller should use fallback).
    public func drawQuestions(
        subject: Subject,
        difficulty: DifficultyLevel,
        count: Int = GameConstants.challengeRoundSize,
        gradeLevel: GradeLevel
    ) -> [MultipleChoiceQuestion]? {
        let pool = bankData.questions(for: subject)

        // Not enough questions in the bank — signal fallback
        guard pool.count >= GameConstants.bankMinimumForQuiz else {
            return nil
        }

        let recent = recentlyShownIds[subject] ?? []

        // Score each question for selection priority
        // Skip questions with duplicate options (bad AI output)
        let scored: [(index: Int, score: Double)] = pool.enumerated().compactMap { (index, q) in
            // Reject questions with duplicate options
            let uniqueOpts = Set(q.options.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
            guard uniqueOpts.count == q.options.count else { return nil }

            var score: Double = 0

            // Difficulty match: prefer exact, allow adjacent
            if q.difficulty == difficulty {
                score += 100
            } else if abs(q.difficulty.rawValue - difficulty.rawValue) == 1 {
                score += 50
            } else {
                score += 10
            }

            // Penalize recently shown questions heavily
            if recent.contains(q.id) {
                score -= 200
            }

            // Prefer less-shown questions
            score -= Double(q.timesShown) * 5

            // Penalize mastered questions (but don't exclude — may be needed)
            if q.isMastered {
                score -= 50
            }

            // Random jitter for variety
            score += Double.random(in: 0...10)

            return (index, score)
        }

        // Sort by score descending, take top N
        let sorted = scored.sorted { $0.score > $1.score }
        let selected = sorted.prefix(count)

        var drawnQuestions: [MultipleChoiceQuestion] = []
        var drawnIds: [UUID] = []

        for item in selected {
            let banked = pool[item.index]
            drawnQuestions.append(banked.toMultipleChoiceQuestion())
            drawnIds.append(banked.id)

            // Update tracking in-place
            bankData.banks[subject.rawValue]?[item.index].timesShown += 1
            bankData.banks[subject.rawValue]?[item.index].lastShownDate = Date()
        }

        // Update recently-shown tracking (sliding window)
        var updatedRecent = recent + drawnIds
        let windowSize = GameConstants.bankRecentlyShownWindow
        if updatedRecent.count > windowSize {
            updatedRecent = Array(updatedRecent.suffix(windowSize))
        }
        recentlyShownIds[subject] = updatedRecent

        // Persist the timesShown updates
        saveBank()

        return drawnQuestions.isEmpty ? nil : drawnQuestions
    }

    // MARK: - Draw Mixed Questions

    /// Draw a mixed set of questions (multiple types) for a challenge round.
    /// Combines MC questions from the adaptive bank with new-type questions
    /// from the static NewTypeQuestionBank for variety.
    /// Returns nil if not enough questions are available (caller should fallback).
    public func drawMixedQuestions(
        subject: Subject,
        difficulty: DifficultyLevel,
        count: Int = GameConstants.challengeRoundSize,
        gradeLevel: GradeLevel
    ) -> [Question]? {
        // Get new-type questions available for this subject
        let newTypePool = NewTypeQuestionBank.questions(for: subject).shuffled()

        // Try to draw MC questions from the adaptive bank
        let mcCount = max(1, count - min(2, newTypePool.count))  // At least 1 MC, up to 2 new-type
        let newTypeCount = count - mcCount

        // Draw MC questions from adaptive bank
        guard let mcQuestions = drawQuestions(
            subject: subject,
            difficulty: difficulty,
            count: mcCount,
            gradeLevel: gradeLevel
        ) else {
            // Bank doesn't have enough MC — try pure new-type round
            guard newTypePool.count >= count else { return nil }
            return Array(newTypePool.prefix(count))
        }

        // Convert MC to universal Question type
        var mixed: [Question] = mcQuestions.map { $0.toQuestion() }

        // Add new-type questions
        if newTypeCount > 0 && !newTypePool.isEmpty {
            let newTypes = Array(newTypePool.prefix(newTypeCount))
            mixed.append(contentsOf: newTypes)
        }

        // Shuffle to interleave question types
        mixed.shuffle()

        return mixed.isEmpty ? nil : mixed
    }

    // MARK: - Record Results (Universal Question)

    /// Record quiz results for universal Question types.
    /// MC questions are matched to the adaptive bank; non-MC types are tracked by subject only.
    public func recordResults(
        subject: Subject,
        questions: [Question],
        results: [Bool]
    ) {
        // Extract MC questions and record them against the adaptive bank
        var mcQuestions: [MultipleChoiceQuestion] = []
        var mcResults: [Bool] = []
        for (i, q) in questions.enumerated() {
            guard i < results.count else { break }
            if let mc = q.toMultipleChoiceQuestion() {
                mcQuestions.append(mc)
                mcResults.append(results[i])
            }
        }
        if !mcQuestions.isEmpty {
            recordResults(subject: subject, questions: mcQuestions, results: mcResults)
        }
    }

    // MARK: - Record Quiz Results

    /// Record quiz results — tracks which questions the player got correct.
    /// Called after challenge completion with the original questions and per-question results.
    public func recordResults(
        subject: Subject,
        questions: [MultipleChoiceQuestion],
        results: [Bool]
    ) {
        guard var bank = bankData.banks[subject.rawValue] else { return }

        for (i, mcq) in questions.enumerated() {
            guard i < results.count else { break }

            // Find matching banked question by question text
            let normalized = mcq.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let bankIndex = bank.firstIndex(where: {
                $0.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized
            }) {
                if results[i] {
                    bank[bankIndex].timesCorrect += 1
                }
            }
        }

        bankData.banks[subject.rawValue] = bank
        saveBank()
    }

    // MARK: - Background AI Replenishment

    /// Analyze quiz performance and replenish the bank in the background.
    /// Runs as a detached Task — does NOT block gameplay.
    public func replenishAfterQuiz(
        subject: Subject,
        difficulty: DifficultyLevel,
        gradeLevel: GradeLevel,
        quizResults: [Bool]
    ) {
        guard isReplenishing[subject] != true else {
            print("[QuestionBank] Already replenishing \(subject.rawValue), skipping")
            return
        }
        isReplenishing[subject] = true

        Task { [weak self] in
            guard let self = self else { return }
            defer { self.isReplenishing[subject] = false }

            // 1. Remove mastered questions that haven't been shown recently
            self.removeMasteredQuestions(for: subject)

            // 2. Calculate how many questions we need to reach the target
            let currentCount = self.bankData.questions(for: subject).count
            let deficit = GameConstants.bankQuestionsPerSubject - currentCount

            guard deficit > 0 else {
                print("[QuestionBank] \(subject.rawValue) bank is full (\(currentCount) questions)")
                self.saveBank()
                return
            }

            // 3. Determine target difficulty based on quiz performance
            let accuracy = quizResults.isEmpty
                ? 0.5
                : Double(quizResults.filter { $0 }.count) / Double(quizResults.count)

            let targetDifficulty: DifficultyLevel
            if accuracy >= GameConstants.difficultyIncreaseThreshold {
                targetDifficulty = difficulty.next   // Player acing it — generate harder
            } else if accuracy <= GameConstants.difficultyDecreaseThreshold {
                targetDifficulty = difficulty.previous  // Struggling — generate easier
            } else {
                targetDifficulty = difficulty  // Sweet spot — same level
            }

            // 4. Generate new AI questions
            let toGenerate = min(deficit, GameConstants.bankReplenishBatchSize)
            var generated = 0
            var usedTexts: Set<String> = Set(
                self.bankData.questions(for: subject).map {
                    $0.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                }
            )

            for _ in 0..<toGenerate {
                if let aiQ = await self.questionGenerator.generateQuestion(
                    subject: subject.rawValue,
                    gradeLevel: gradeLevel.rawValue,
                    difficulty: targetDifficulty.rawValue
                ) {
                    let normalized = aiQ.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !usedTexts.contains(normalized) else { continue }
                    usedTexts.insert(normalized)

                    let mcq = MultipleChoiceQuestion(
                        question: aiQ.question,
                        options: aiQ.options,
                        correctIndex: aiQ.correctIndex,
                        explanation: aiQ.explanation,
                        subject: subject,
                        difficulty: targetDifficulty,
                        gradeLevel: gradeLevel
                    )

                    let banked = BankedQuestion(from: mcq, source: .aiGenerated)
                    var questions = self.bankData.questions(for: subject)
                    questions.append(banked)
                    self.bankData.setQuestions(questions, for: subject)
                    generated += 1
                }
            }

            // 5. If AI didn't generate enough, fill from static bank
            if generated < toGenerate {
                self.fillFromStaticBank(
                    subject: subject,
                    difficulty: targetDifficulty,
                    needed: toGenerate - generated
                )
            }

            self.bankData.lastReplenishDate[subject.rawValue] = Date()
            self.saveBank()

            let finalCount = self.bankData.questions(for: subject).count
            print("[QuestionBank] Replenished \(subject.rawValue): +\(generated) AI, now \(finalCount) total")
        }
    }

    /// Remove questions the player has mastered and haven't been shown recently.
    private func removeMasteredQuestions(for subject: Subject) {
        let questions = bankData.questions(for: subject)
        let now = Date()
        let minBankSize = GameConstants.bankMinimumForQuiz * 2  // Never go below 2x quiz size

        // Only remove if bank is large enough
        guard questions.count > minBankSize else { return }

        // Find indices of mastered questions eligible for removal
        var toRemove: [Int] = []
        for (index, q) in questions.enumerated() {
            guard q.isMastered,
                  let lastShown = q.lastShownDate,
                  now.timeIntervalSince(lastShown) > GameConstants.bankMasteryRemovalDelay else {
                continue
            }
            toRemove.append(index)
            // Stop if removing more would drop below minimum
            if questions.count - toRemove.count <= minBankSize {
                break
            }
        }

        guard !toRemove.isEmpty else { return }

        // Build new array excluding removed indices
        let removeSet = Set(toRemove)
        let filtered = questions.enumerated().compactMap { (i, q) in
            removeSet.contains(i) ? nil : q
        }

        bankData.setQuestions(filtered, for: subject)
        print("[QuestionBank] Removed \(toRemove.count) mastered questions from \(subject.rawValue)")
    }

    /// Fill bank gaps from the static QuestionBank.
    private func fillFromStaticBank(subject: Subject, difficulty: DifficultyLevel, needed: Int) {
        let existing = Set(bankData.questions(for: subject).map {
            $0.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        })

        var pool = QuestionBank.questions(for: subject, difficulty: difficulty).shuffled()

        // Also try adjacent difficulties if not enough
        let allDifficulties: [DifficultyLevel] = [.beginner, .easy, .medium, .hard, .advanced]
        if pool.count < needed {
            for diff in allDifficulties where diff != difficulty {
                pool.append(contentsOf: QuestionBank.questions(for: subject, difficulty: diff).shuffled())
            }
        }

        var added = 0
        var questions = bankData.questions(for: subject)

        for mcq in pool {
            guard added < needed else { break }
            let normalized = mcq.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !existing.contains(normalized) else { continue }
            questions.append(BankedQuestion(from: mcq, source: .staticBank))
            added += 1
        }

        if added > 0 {
            bankData.setQuestions(questions, for: subject)
            print("[QuestionBank] Filled \(added) questions from static bank for \(subject.rawValue)")
        }
    }

    // MARK: - Initial Seeding

    /// Quick-seed: load static questions only (instant, no AI calls).
    /// Makes the bank quiz-ready immediately. AI questions are added separately in background.
    public func quickSeedFromStatic(subject: Subject) {
        var questions: [BankedQuestion] = bankData.questions(for: subject)
        var usedTexts: Set<String> = Set(questions.map {
            $0.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        })

        let allDifficulties: [DifficultyLevel] = [.beginner, .easy, .medium, .hard, .advanced]
        for diff in allDifficulties {
            let pool = QuestionBank.questions(for: subject, difficulty: diff).shuffled()
            for mcq in pool {
                guard questions.count < GameConstants.bankSeedStaticCount else { break }
                let normalized = mcq.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !usedTexts.contains(normalized) else { continue }
                usedTexts.insert(normalized)
                questions.append(BankedQuestion(from: mcq, source: .staticBank))
            }
        }

        bankData.setQuestions(questions, for: subject)
        saveBank()
        print("[QuestionBank] Quick-seeded \(subject.rawValue) with \(questions.count) static questions")
    }

    /// Generate AI questions for a subject in the background (non-blocking).
    /// Called after quick-seed to enrich the bank with grade-appropriate AI content.
    private func enrichWithAI(
        subject: Subject,
        difficulty: DifficultyLevel,
        gradeLevel: GradeLevel
    ) async {
        let currentCount = bankData.questions(for: subject).count
        let deficit = GameConstants.bankQuestionsPerSubject - currentCount
        guard deficit > 0 else { return }

        let toGenerate = min(deficit, GameConstants.bankSeedAICount)
        var usedTexts: Set<String> = Set(
            bankData.questions(for: subject).map {
                $0.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )

        var aiGenerated = 0
        for _ in 0..<toGenerate {
            if let aiQ = await questionGenerator.generateQuestion(
                subject: subject.rawValue,
                gradeLevel: gradeLevel.rawValue,
                difficulty: difficulty.rawValue
            ) {
                let normalized = aiQ.question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !usedTexts.contains(normalized) else { continue }
                usedTexts.insert(normalized)

                let mcq = MultipleChoiceQuestion(
                    question: aiQ.question,
                    options: aiQ.options,
                    correctIndex: aiQ.correctIndex,
                    explanation: aiQ.explanation,
                    subject: subject,
                    difficulty: difficulty,
                    gradeLevel: gradeLevel
                )

                var questions = bankData.questions(for: subject)
                questions.append(BankedQuestion(from: mcq, source: .aiGenerated))
                bankData.setQuestions(questions, for: subject)
                aiGenerated += 1
            }
        }

        if aiGenerated > 0 {
            bankData.lastReplenishDate[subject.rawValue] = Date()
            saveBank()
            let total = bankData.questions(for: subject).count
            print("[QuestionBank] Enriched \(subject.rawValue) with \(aiGenerated) AI questions (total: \(total))")
        }
    }

    /// Check if a subject's bank needs seeding (too few questions for a quiz).
    public func needsSeeding(for subject: Subject) -> Bool {
        bankData.questions(for: subject).count < GameConstants.bankMinimumForQuiz
    }

    // MARK: - Startup Pre-Seeding

    /// Pre-seed all subjects at app launch.
    /// Step 1 (instant): Load static questions for ALL subjects — makes bank quiz-ready.
    /// Step 2 (background): Enrich each subject with AI-generated questions.
    public func seedAllSubjectsIfNeeded(
        difficulty: DifficultyLevel,
        gradeLevel: GradeLevel
    ) {
        // Step 1: Instant static seed for any subject that needs it
        let subjectsToSeed = Subject.allCases.filter { needsSeeding(for: $0) }
        if !subjectsToSeed.isEmpty {
            for subject in subjectsToSeed {
                quickSeedFromStatic(subject: subject)
            }
            print("[QuestionBank] Quick-seeded \(subjectsToSeed.count) subject(s) from static bank")
        }

        // Step 2: Enrich with AI questions in background (non-blocking)
        let subjectsNeedingAI = Subject.allCases.filter { sub in
            bankData.questions(for: sub).count < GameConstants.bankQuestionsPerSubject
        }
        guard !subjectsNeedingAI.isEmpty else {
            print("[QuestionBank] All subject banks are fully stocked — no AI enrichment needed")
            return
        }

        print("[QuestionBank] Enriching \(subjectsNeedingAI.count) subject(s) with AI in background")

        Task { [weak self] in
            guard let self = self else { return }
            for subject in subjectsNeedingAI {
                await self.enrichWithAI(
                    subject: subject,
                    difficulty: difficulty,
                    gradeLevel: gradeLevel
                )
            }
            print("[QuestionBank] Background AI enrichment complete")
        }
    }
}
