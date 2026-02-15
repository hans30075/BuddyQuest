import Foundation

/// Generates contextual buddy dialogue using AI, with offline fallback to pre-written lines.
public final class BuddyDialogueGenerator {

    private let manager = AIServiceManager.shared

    public init() {}

    /// Generate a contextual dialogue line for the active buddy.
    /// Returns nil if AI is unavailable (caller should use BuddyCharacter's built-in lines).
    public func generateDialogue(
        buddyType: String,
        context: BuddyDialogueContext
    ) async -> AIBuddyDialogue? {
        guard manager.isAIEnabled,
              let service = manager.activeService,
              manager.checkRateLimit() else {
            return nil // Use offline buddy lines
        }

        let personality = PromptTemplates.personalityDescription(for: buddyType)

        do {
            let result = try await service.generateBuddyDialogue(
                buddyName: buddyType.capitalized,
                buddyPersonality: personality,
                context: context
            )
            manager.recordCall()

            // Validate — dialogue shouldn't be too long for a speech bubble
            guard result.dialogue.count <= 200 else {
                // Truncate at sentence boundary
                let truncated = truncateAtSentence(result.dialogue, maxLength: 150)
                return AIBuddyDialogue(dialogue: truncated, emotion: result.emotion)
            }

            return result
        } catch {
            print("[BuddyDialogueGenerator] AI error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Truncate text at the nearest sentence boundary
    private func truncateAtSentence(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let substring = String(text.prefix(maxLength))
        // Find last sentence-ending punctuation
        if let lastPeriod = substring.lastIndex(where: { ".!?".contains($0) }) {
            return String(substring[...lastPeriod])
        }
        return substring + "..."
    }
}
