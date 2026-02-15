import Foundation

/// Generates progressive Socratic hints through the buddy's personality.
/// 4 hint levels from vague to specific, never directly giving away the answer (except level 4).
public final class SocraticTutor {

    private let manager = AIServiceManager.shared

    public init() {}

    /// Generate a hint at the specified level (1-4).
    /// Returns nil if AI is unavailable (caller should use generic offline hints).
    public func generateHint(
        question: String,
        options: [String],
        correctIndex: Int,
        hintLevel: Int,
        buddyType: String
    ) async -> AIHint? {
        guard manager.isAIEnabled,
              let service = manager.activeService,
              manager.checkRateLimit() else {
            return offlineHint(question: question, options: options,
                             correctIndex: correctIndex, hintLevel: hintLevel, buddyType: buddyType)
        }

        let personality = PromptTemplates.personalityDescription(for: buddyType)

        do {
            let hint = try await service.generateHint(
                question: question,
                options: options,
                correctIndex: correctIndex,
                hintLevel: hintLevel,
                buddyName: buddyType.capitalized,
                buddyPersonality: personality
            )
            manager.recordCall()
            return hint
        } catch {
            print("[SocraticTutor] AI error: \(error.localizedDescription), using offline hint")
            return offlineHint(question: question, options: options,
                             correctIndex: correctIndex, hintLevel: hintLevel, buddyType: buddyType)
        }
    }

    // MARK: - Offline Hints

    /// Generate a generic hint without AI
    private func offlineHint(
        question: String,
        options: [String],
        correctIndex: Int,
        hintLevel: Int,
        buddyType: String
    ) -> AIHint {
        let correctAnswer = correctIndex < options.count ? options[correctIndex] : "the correct answer"
        let buddyName = buddyType.capitalized

        switch hintLevel {
        case 1:
            // Level 1: Restate / encourage
            let hints = [
                "Hmm, let me think about this with you! Read the question one more time carefully.",
                "Take your time! Sometimes the answer is hidden in the question itself.",
                "No rush! Think about what you already know about this topic."
            ]
            return AIHint(hintText: "\(buddyName) says: \(hints.randomElement()!)", hintLevel: 1)

        case 2:
            // Level 2: Point to concept
            let hints = [
                "Try to eliminate the options that definitely don't fit.",
                "Think about what makes sense — which options can you rule out?",
                "Focus on the key words in the question. What are they really asking?"
            ]
            return AIHint(hintText: "\(buddyName) says: \(hints.randomElement()!)", hintLevel: 2)

        case 3:
            // Level 3: Narrow down to 2
            let wrongIndex = (0..<options.count).filter { $0 != correctIndex }.randomElement() ?? 0
            let otherWrongIndex = (0..<options.count).filter { $0 != correctIndex && $0 != wrongIndex }.first ?? 0
            return AIHint(
                hintText: "\(buddyName) says: I don't think it's \"\(options[wrongIndex])\" or \"\(options[otherWrongIndex])\". What do you think about the other two?",
                hintLevel: 3
            )

        case 4:
            // Level 4: Walk through to answer
            return AIHint(
                hintText: "\(buddyName) says: The answer is \"\(correctAnswer)\"! Let's remember this for next time.",
                hintLevel: 4
            )

        default:
            return AIHint(hintText: "\(buddyName) says: You've got this! Think it through.", hintLevel: hintLevel)
        }
    }
}
