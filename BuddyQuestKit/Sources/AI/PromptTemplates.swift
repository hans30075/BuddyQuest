import Foundation

/// Centralized prompt templates for all AI operations.
/// Each method returns a system prompt + user prompt pair.
public enum PromptTemplates {

    // MARK: - Question Generation

    public static func questionGeneration(
        subject: String,
        topic: String?,
        gradeLevel: Int,
        difficulty: Int
    ) -> (system: String, user: String) {
        let gradeName = gradeLevel == 0 ? "Kindergarten" : "Grade \(gradeLevel)"
        let topicLine = topic.map { " about \($0)" } ?? ""
        let difficultyName = ["", "beginner", "easy", "medium", "hard", "advanced"][min(difficulty, 5)]

        let subjectExamples: String
        switch subject.lowercased() {
        case "language arts":
            subjectExamples = "Topics: grammar, vocabulary, reading comprehension, spelling, parts of speech, punctuation, synonyms, antonyms, sentence structure, rhyming, prefixes, suffixes."
        case "math":
            subjectExamples = """
            Topics: addition, subtraction, multiplication, division, fractions, geometry, patterns, measurement, word problems, place value, number sense.
            CRITICAL MATH RULES:
            1. You MUST compute the correct answer step by step before setting correctIndex. Double-check ALL arithmetic.
            2. The correctIndex MUST point to the option that equals the computed answer.
            3. Prefer clear, unambiguous questions. For word problems, state all quantities clearly so there is exactly ONE correct interpretation.
            4. The explanation MUST show the same arithmetic as the answer. If your explanation says "40 ÷ 5 = 8", then the correct option MUST be 8.
            5. NEVER generate a word problem where the answer depends on interpretation or rounding assumptions.
            6. Example of GOOD question: "What is 7 × 5?" with correct answer 35.
            7. Example of BAD question: "A teacher has 40 students and 5 pencils per pack, how many packs?" (ambiguous — 40 students needing packs vs 40 pencils total).
            """
        case "science":
            subjectExamples = "Topics: animals, plants, weather, space, human body, states of matter, energy, ecosystems, simple machines, rocks, magnets."
        case "social skills":
            subjectExamples = "Topics: teamwork, sharing, empathy, conflict resolution, friendship, communication, kindness, respect, cooperation, feelings."
        default:
            subjectExamples = ""
        }

        let system = """
        You are an educational content generator for a children's learning game (ages 5-13). \
        You ONLY generate \(subject) questions. Never generate questions about other subjects. \
        Always respond with valid JSON only, no markdown or extra text.
        """

        let user = """
        Generate a \(gradeName) \(subject) multiple-choice question\(topicLine). \
        Difficulty: \(difficultyName) (\(difficulty)/5). \
        \(subjectExamples)

        CRITICAL: This question MUST be about \(subject). Do NOT ask about other subjects.

        Return JSON with this exact structure:
        {"question":"<question text ONLY, no answer choices>","options":["<full text of option 1>","<full text of option 2>","<full text of option 3>","<full text of option 4>"],"correctIndex":0,"explanation":"..."}

        Rules:
        - "question" must contain ONLY the question text. Do NOT include A), B), C), D) options in the question.
        - "options" must be an array of 4 full answer strings (e.g. ["Mercury", "Venus", "Earth", "Mars"]), NOT single letters.
        - The question MUST test \(subject) knowledge — nothing else.
        - Question must be factually accurate and age-appropriate for \(gradeName)
        - Exactly 4 options, exactly 1 correct
        - correctIndex is 0-based (0 to 3)
        - Explanation should be brief and encouraging (1-2 sentences)
        - MATH ONLY: Before finalizing, verify the arithmetic. Compute the answer step by step. The option at correctIndex MUST equal the computed answer. Getting the math wrong is the worst possible error.
        """

        return (system, user)
    }

    // MARK: - Answer Grading

    public static func answerGrading(
        question: String,
        correctAnswer: String,
        studentAnswer: String,
        subject: String
    ) -> (system: String, user: String) {
        let system = """
        You are a kind, encouraging teacher grading a child's answer in an educational game. \
        Be supportive and constructive. Respond with valid JSON only.
        """

        let user = """
        Grade this student's answer:
        Subject: \(subject)
        Question: \(question)
        Correct answer: \(correctAnswer)
        Student's answer: \(studentAnswer)

        Return JSON: {"score":0-100,"isCorrect":true/false,"feedback":"...","explanation":"..."}
        Rules:
        - score: 0-100 (allow partial credit for close answers)
        - isCorrect: true if score >= 70
        - feedback: 1 sentence, encouraging and age-appropriate (start with positive)
        - explanation: 1-2 sentences explaining the correct answer
        """

        return (system, user)
    }

    // MARK: - Socratic Hints

    public static func socraticHint(
        question: String,
        options: [String],
        correctIndex: Int,
        hintLevel: Int,
        buddyName: String,
        buddyPersonality: String
    ) -> (system: String, user: String) {
        let optionsList = options.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let levelDescription: String
        switch hintLevel {
        case 1: levelDescription = "Restate the question in a simpler way. Do NOT reveal the answer."
        case 2: levelDescription = "Point to the relevant concept or topic area. Do NOT reveal the answer."
        case 3: levelDescription = "Give an analogy or partial clue that narrows it down to 2 options."
        case 4: levelDescription = "Walk through the reasoning step by step, leading to the correct answer."
        default: levelDescription = "Give a gentle nudge toward the right direction."
        }

        let system = """
        You are \(buddyName), a companion character in a children's educational game. \
        Personality: \(buddyPersonality). \
        Speak in character as \(buddyName). Keep responses under 2 sentences. \
        Respond with valid JSON only.
        """

        let user = """
        The student is stuck on this question. Give a level \(hintLevel) hint.
        Question: \(question)
        Options:
        \(optionsList)
        Correct answer: option \(correctIndex + 1)

        Hint level \(hintLevel) instruction: \(levelDescription)

        Return JSON: {"hintText":"...(in character as \(buddyName))","hintLevel":\(hintLevel)}
        """

        return (system, user)
    }

    // MARK: - Buddy Dialogue

    public static func buddyDialogue(
        buddyName: String,
        buddyPersonality: String,
        context: BuddyDialogueContext
    ) -> (system: String, user: String) {
        let system = """
        You are \(buddyName), a companion character in a children's educational RPG game. \
        Personality: \(buddyPersonality). \
        Keep responses short (1-2 sentences max), fun, and in character. \
        Respond with valid JSON only.
        """

        var contextParts: [String] = []
        contextParts.append("Trigger: \(context.trigger)")
        if let zone = context.zoneName { contextParts.append("Current zone: \(zone)") }
        contextParts.append("Player level: \(context.playerLevel)")
        if let perf = context.recentPerformance { contextParts.append("Recent performance: \(perf)") }
        if let extra = context.additionalContext { contextParts.append("Context: \(extra)") }

        let user = """
        Generate a short in-character dialogue line for \(buddyName).
        \(contextParts.joined(separator: "\n"))

        Return JSON: {"dialogue":"...(1-2 sentences, in character)","emotion":"happy/thinking/excited/encouraging"}
        """

        return (system, user)
    }

    // MARK: - Buddy Personality Descriptions

    public static func personalityDescription(for buddyType: String) -> String {
        switch buddyType.lowercased() {
        case "nova":
            return "Curious and analytical. Loves science and asking 'why?' and 'how?'. Uses science metaphors. Excited by experiments and discovery."
        case "lexie":
            return "Creative and expressive. Loves words, stories, and poetry. Uses colorful language. Encouraging about writing and reading."
        case "digit":
            return "Logical and patient. Loves numbers, patterns, and puzzles. Breaks problems into steps. Celebrates finding patterns."
        case "harmony":
            return "Empathetic and warm. Loves teamwork and helping others. Uses kind, inclusive language. Celebrates cooperation."
        default:
            return "Friendly, encouraging, and supportive learning companion."
        }
    }
}
