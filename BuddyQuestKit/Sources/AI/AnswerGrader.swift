import Foundation

/// AI-powered answer grading with offline fallback (keyword/fuzzy matching).
public final class AnswerGrader {

    private let manager = AIServiceManager.shared

    public init() {}

    /// Grade a student's short answer using AI if available, otherwise fuzzy match.
    public func gradeAnswer(
        question: String,
        correctAnswer: String,
        studentAnswer: String,
        subject: String
    ) async -> AIGradingResult {
        // Try AI grading
        if manager.isAIEnabled,
           let service = manager.activeService,
           manager.checkRateLimit() {
            do {
                let result = try await service.gradeAnswer(
                    question: question,
                    correctAnswer: correctAnswer,
                    studentAnswer: studentAnswer,
                    subject: subject
                )
                manager.recordCall()
                return result
            } catch {
                print("[AnswerGrader] AI error: \(error.localizedDescription), using offline grading")
            }
        }

        // Offline fallback: keyword/fuzzy matching
        return offlineGrade(correctAnswer: correctAnswer, studentAnswer: studentAnswer)
    }

    // MARK: - Offline Grading

    private func offlineGrade(correctAnswer: String, studentAnswer: String) -> AIGradingResult {
        let correct = correctAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let student = studentAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match
        if student == correct {
            return AIGradingResult(
                score: 100, isCorrect: true,
                feedback: "That's exactly right! Great job!",
                explanation: "Your answer matches perfectly."
            )
        }

        // Contains match (student answer contains the key phrase)
        if student.contains(correct) || correct.contains(student) {
            return AIGradingResult(
                score: 85, isCorrect: true,
                feedback: "Very close! You've got the right idea!",
                explanation: "The correct answer is: \(correctAnswer)"
            )
        }

        // Word overlap scoring
        let correctWords = Set(correct.split(separator: " ").map(String.init))
        let studentWords = Set(student.split(separator: " ").map(String.init))
        let overlap = correctWords.intersection(studentWords).count
        let totalWords = max(correctWords.count, 1)
        let overlapScore = Int(Double(overlap) / Double(totalWords) * 100)

        if overlapScore >= 60 {
            return AIGradingResult(
                score: overlapScore, isCorrect: true,
                feedback: "Good thinking! You're on the right track.",
                explanation: "The correct answer is: \(correctAnswer)"
            )
        }

        // Levenshtein distance for close misspellings
        let distance = levenshteinDistance(student, correct)
        let maxLen = max(correct.count, 1)
        let similarity = max(0, 100 - (distance * 100 / maxLen))

        if similarity >= 70 {
            return AIGradingResult(
                score: similarity, isCorrect: true,
                feedback: "Almost! Just a small spelling difference.",
                explanation: "The correct answer is: \(correctAnswer)"
            )
        }

        return AIGradingResult(
            score: max(similarity, overlapScore),
            isCorrect: false,
            feedback: "Nice try! Let's learn from this one.",
            explanation: "The correct answer is: \(correctAnswer)"
        )
    }

    // MARK: - Levenshtein Distance

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,       // deletion
                    matrix[i][j - 1] + 1,       // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        return matrix[m][n]
    }
}
