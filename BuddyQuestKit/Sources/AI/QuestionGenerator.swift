import Foundation

/// High-level question generation that tries AI first, falls back to QuestionBank.
public final class QuestionGenerator {

    private let manager = AIServiceManager.shared
    private let mathValidator = MathAnswerValidator()

    public init() {}

    /// Generate a question using AI if available, otherwise fall back to the offline bank.
    /// Returns a tuple of (question, options, correctIndex, explanation) matching
    /// what MultipleChoiceChallenge expects.
    public func generateQuestion(
        subject: String,
        gradeLevel: Int,
        difficulty: Int
    ) async -> AIGeneratedQuestion? {
        // Check if AI is available and within rate limits
        guard manager.isAIEnabled,
              let service = manager.activeService,
              manager.checkRateLimit() else {
            return nil // Caller should use QuestionBank
        }

        do {
            let question = try await service.generateQuestion(
                subject: subject,
                topic: nil,
                gradeLevel: gradeLevel,
                difficulty: difficulty
            )

            // Validate the response
            guard question.options.count == 4,
                  question.correctIndex >= 0 && question.correctIndex < 4,
                  !question.question.isEmpty else {
                print("[QuestionGenerator] AI returned invalid question, falling back to bank")
                return nil
            }

            manager.recordCall()

            // Sanitize: strip any embedded A)/B)/C)/D) options from question text
            let cleanedQuestion = sanitizeQuestionText(question.question)

            // Sanitize: if options are just single letters (A/B/C/D), the AI messed up
            let hasRealOptions = question.options.contains { $0.count > 2 }
            guard hasRealOptions else {
                print("[QuestionGenerator] AI returned letter-only options, falling back to bank")
                return nil
            }

            // Validate: check that the question is on-topic for the requested subject
            let allText = (cleanedQuestion + " " + question.options.joined(separator: " ")).lowercased()
            if !isOnTopic(text: allText, subject: subject) {
                print("[QuestionGenerator] AI returned off-topic question for \(subject), falling back to bank")
                return nil
            }

            // Build the sanitized question
            var finalQuestion = AIGeneratedQuestion(
                question: cleanedQuestion,
                options: question.options,
                correctIndex: question.correctIndex,
                explanation: question.explanation,
                difficulty: question.difficulty,
                subject: question.subject,
                gradeLevel: question.gradeLevel
            )

            // ✅ MATH ACCURACY: Verify arithmetic answers independently
            if subject.lowercased() == "math" {
                if let validated = mathValidator.validate(question: finalQuestion) {
                    finalQuestion = validated
                } else {
                    // Math validation detected an error that couldn't be fixed — reject
                    print("[QuestionGenerator] AI math answer is wrong, falling back to bank")
                    return nil
                }
            }

            // ✅ FACTUAL CHECKS: Verify options and content where possible
            if let validated = factualValidator(question: finalQuestion, subject: subject) {
                finalQuestion = validated
            } else {
                // Factual validator rejected the question (e.g. duplicate options)
                print("[QuestionGenerator] Factual validation rejected question, falling back to bank")
                return nil
            }

            return finalQuestion

        } catch {
            print("[QuestionGenerator] AI error: \(error.localizedDescription), falling back to bank")
            return nil
        }
    }

    // MARK: - Subject Validation

    /// Check that the AI question is actually about the requested subject.
    /// Uses keyword heuristics to catch obvious off-topic questions.
    /// Returns true if the question appears to be on-topic (or if we can't tell).
    private func isOnTopic(text: String, subject: String) -> Bool {
        // Define keywords that are strong indicators of each subject
        let scienceKeywords: Set<String> = [
            "rock", "mineral", "granite", "basalt", "limestone", "sandstone",
            "planet", "solar system", "orbit", "gravity", "atom", "molecule",
            "photosynthesis", "ecosystem", "habitat", "species", "fossil",
            "magnet", "electricity", "chemical", "element", "periodic table",
            "cell", "organism", "bacteria", "virus", "dna", "evolution",
            "volcano", "earthquake", "weather", "climate", "temperature",
            "boil", "freeze", "melt", "evaporate", "condensation",
            "energy", "force", "motion", "velocity", "acceleration",
            "mammal", "reptile", "amphibian", "insect", "vertebrate",
        ]
        let mathKeywords: Set<String> = [
            "calculate", "equation", "multiply", "divide", "fraction",
            "decimal", "percent", "area", "perimeter", "volume",
            "triangle", "rectangle", "circle", "square root", "exponent",
            "algebra", "geometry", "probability", "ratio", "proportion",
            "sum", "difference", "product", "quotient", "integer",
        ]
        let languageArtsKeywords: Set<String> = [
            "noun", "verb", "adjective", "adverb", "pronoun", "preposition",
            "synonym", "antonym", "rhyme", "syllable", "prefix", "suffix",
            "punctuation", "comma", "period", "apostrophe", "quotation",
            "sentence", "paragraph", "essay", "narrative", "fiction",
            "metaphor", "simile", "alliteration", "onomatopoeia",
            "spelling", "vocabulary", "grammar", "conjugat", "tense",
            "plural", "singular", "contraction", "homophone", "homonym",
        ]
        let socialKeywords: Set<String> = [
            "teamwork", "cooperat", "empathy", "kindness", "sharing",
            "conflict resolution", "bullying", "feelings", "emotion",
            "respect", "responsib", "citizen", "community", "volunteer",
            "fairness", "integrity", "compassion", "inclusion",
        ]

        let words = text.lowercased()

        // Count how many keywords from each subject appear in the text
        func keywordHits(_ keywords: Set<String>) -> Int {
            keywords.filter { words.contains($0) }.count
        }

        let scienceHits = keywordHits(scienceKeywords)
        let mathHits = keywordHits(mathKeywords)
        let langHits = keywordHits(languageArtsKeywords)
        let socialHits = keywordHits(socialKeywords)

        // If no strong signals, allow it through (benefit of the doubt)
        let totalHits = scienceHits + mathHits + langHits + socialHits
        guard totalHits >= 2 else { return true }

        // Check if the dominant subject matches the requested subject
        let subjectLower = subject.lowercased()
        switch subjectLower {
        case "language arts":
            // Reject if science or math keywords dominate
            return langHits >= scienceHits && langHits >= mathHits
        case "math":
            return mathHits >= scienceHits && mathHits >= langHits
        case "science":
            return scienceHits >= mathHits && scienceHits >= langHits
        case "social skills":
            return socialHits >= scienceHits && socialHits >= mathHits
        default:
            return true
        }
    }

    // MARK: - Sanitization

    /// Strip embedded answer options from the question text.
    /// AI sometimes returns: "What is 2+2?\nA) 3\nB) 4\nC) 5\nD) 6"
    /// We only want: "What is 2+2?"
    private func sanitizeQuestionText(_ text: String) -> String {
        // Pattern: newline followed by A)/B)/C)/D) or A./B./C./D. or (A)/(B)/(C)/(D)
        // Remove everything from the first occurrence of such a pattern
        let patterns = [
            #"\n\s*[Aa]\s*[\)\.\:]"#,    // \nA) or \na) or \nA. or \nA:
            #"\n\s*\([Aa]\)"#,             // \n(A) or \n(a)
            #"\n\s*1[\)\.\:]"#,            // \n1) or \n1. or \n1:
        ]

        var cleaned = text
        for pattern in patterns {
            if let range = cleaned.range(of: pattern, options: .regularExpression) {
                cleaned = String(cleaned[..<range.lowerBound])
                break
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Factual Validation (non-math)

    /// Basic factual checks for science and language arts questions.
    /// Returns nil if the question seems okay, or a corrected version if we can fix it.
    /// Unlike math, we can't compute science/language answers programmatically,
    /// but we can check for some common patterns of AI errors.
    private func factualValidator(question: AIGeneratedQuestion, subject: String) -> AIGeneratedQuestion? {
        // Check for duplicate options (AI sometimes returns the same answer twice)
        let uniqueOptions = Set(question.options.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        if uniqueOptions.count < 4 {
            print("[QuestionGenerator] AI returned duplicate options, rejecting")
            return nil  // nil signals "reject this question"
        }

        // Check that the "correct" option is not empty
        let correctOption = question.options[question.correctIndex]
        if correctOption.trimmingCharacters(in: .whitespaces).isEmpty {
            print("[QuestionGenerator] AI correct answer is empty, rejecting")
            return nil
        }

        // Passed basic checks — return question as-is
        return question
    }
}

// MARK: - Math Answer Validator

/// Independently computes answers for arithmetic math questions to catch AI errors.
/// Supports: addition, subtraction, multiplication, division, percentages, and basic algebra.
struct MathAnswerValidator {

    /// Validate a math question. Returns:
    /// - The corrected question if the answer was wrong but we found the right option
    /// - The original question if it was correct
    /// - nil if the answer is wrong and no option matches the correct answer (reject it)
    func validate(question: AIGeneratedQuestion) -> AIGeneratedQuestion? {
        let text = question.question

        // Try to compute the correct numerical answer
        guard let computedAnswer = computeAnswer(from: text) else {
            // Can't parse this question type (e.g., complex word problems, geometry concepts)
            // — as a fallback, check if the explanation's arithmetic contradicts the answer
            return checkExplanationConsistency(question: question)
        }

        // Find which option matches the computed answer
        let matchIndex = findMatchingOption(answer: computedAnswer, options: question.options)

        if let matchIndex = matchIndex {
            if matchIndex == question.correctIndex {
                // AI got it right!
                return question
            } else {
                // AI marked the wrong option as correct — fix it!
                print("[MathValidator] ⚠️ AI answer wrong! Question: '\(text)' — AI said option \(question.correctIndex) (\(question.options[question.correctIndex])), correct is option \(matchIndex) (\(question.options[matchIndex])) = \(computedAnswer)")
                return AIGeneratedQuestion(
                    question: question.question,
                    options: question.options,
                    correctIndex: matchIndex,
                    explanation: question.explanation,
                    difficulty: question.difficulty,
                    subject: question.subject,
                    gradeLevel: question.gradeLevel
                )
            }
        } else {
            // None of the 4 options match the computed answer — reject entirely
            print("[MathValidator] ❌ No option matches computed answer \(computedAnswer) for: '\(text)'. Options: \(question.options)")
            return nil
        }
    }

    // MARK: - Answer Computation

    /// Try to extract and compute the answer from a math question.
    /// Returns the numerical answer as a Double, or nil if we can't parse it.
    private func computeAnswer(from questionText: String) -> Double? {
        let text = questionText.lowercased()

        // Pattern: "What is A + B?" / "What is A - B?" / "What is A × B?" / "What is A ÷ B?"
        // Also matches: "Calculate A + B", "Solve A + B", "A + B = ?", "A plus B"
        if let result = tryBasicArithmetic(text) { return result }

        // Pattern: "What is X% of Y?"
        if let result = tryPercentOf(text) { return result }

        // Pattern: "What is X^N?" or "What is the value of X^N?"
        if let result = tryExponent(text) { return result }

        // Pattern: "If x + A = B, what is x?" (basic linear algebra)
        if let result = trySimpleAlgebra(text) { return result }

        // Geometry formulas: area, perimeter, volume
        if let result = tryGeometry(text) { return result }

        // Word problems with embedded arithmetic
        if let result = tryWordProblem(text) { return result }

        return nil
    }

    // MARK: - Explanation Consistency Check

    /// Check if the AI's explanation contains arithmetic that contradicts its own answer.
    /// E.g., explanation says "40 ÷ 5 = 8" but correctIndex points to "10 packs".
    /// Returns the corrected question, the original if consistent, or nil if inconsistent and unfixable.
    func checkExplanationConsistency(question: AIGeneratedQuestion) -> AIGeneratedQuestion? {
        // Strip units from explanation so "8 cm x 5 cm = 40 cm²" becomes "8 x 5 = 40"
        let rawExplanation = question.explanation.lowercased()
        let strippedExplanation = rawExplanation
            .replacingOccurrences(of: #"\s*(?:cm³|cm²|cm|mm²|mm|m²|m|in²|in|ft²|ft|km²|km|inches|meters|units|square\s+\w+|cubic\s+\w+)"#, with: "", options: .regularExpression)

        // Try both original and stripped versions
        let explanationsToCheck = [strippedExplanation, rawExplanation]

        // Extract all "A op B = C" patterns from explanation
        // Supports: "8 x 5 = 40", "40 ÷ 5 = 8", "8 × 5 = 40"
        let equationPattern = #"(\d[\d,]*\.?\d*)\s*([+\-×÷\*\/xX])\s*(\d[\d,]*\.?\d*)\s*=\s*(\d[\d,]*\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: equationPattern) else { return question }

        var allMatches: [NSTextCheckingResult] = []
        var matchSource: String = strippedExplanation
        for explanation in explanationsToCheck {
            let matches = regex.matches(in: explanation, range: NSRange(explanation.startIndex..., in: explanation))
            if !matches.isEmpty {
                allMatches = matches
                matchSource = explanation
                break
            }
        }
        let explanation = matchSource
        let matches = allMatches

        for match in matches {
            guard match.numberOfRanges >= 5 else { continue }
            let aStr = extractNumber(from: explanation, range: match.range(at: 1))
            let opStr = extractString(from: explanation, range: match.range(at: 2))
            let bStr = extractNumber(from: explanation, range: match.range(at: 3))
            let resultStr = extractNumber(from: explanation, range: match.range(at: 4))

            guard let a = parseNumber(aStr), let b = parseNumber(bStr), let stated = parseNumber(resultStr) else { continue }

            // Compute what the result should actually be
            let actual: Double?
            switch opStr {
            case "+": actual = a + b
            case "-": actual = a - b
            case "×", "*", "x": actual = a * b
            case "÷", "/": actual = b != 0 ? a / b : nil
            default: actual = nil
            }

            guard let computedResult = actual else { continue }

            // Check if the stated result in the explanation is wrong
            if abs(stated - computedResult) > 0.001 {
                // The explanation's own arithmetic is wrong! This question is unreliable — reject
                print("[MathValidator] ⚠️ Explanation has wrong arithmetic: \(aStr) \(opStr) \(bStr) = \(resultStr) (actual: \(computedResult))")
                return nil
            }

            // The explanation's arithmetic is correct — use that result to verify the correct option
            if let matchIndex = findMatchingOption(answer: computedResult, options: question.options) {
                if matchIndex != question.correctIndex {
                    // The explanation's math says one thing, but correctIndex says another — fix it
                    print("[MathValidator] ⚠️ Explanation math (\(computedResult)) disagrees with correctIndex (\(question.options[question.correctIndex])). Fixing to option \(matchIndex): \(question.options[matchIndex])")
                    return AIGeneratedQuestion(
                        question: question.question,
                        options: question.options,
                        correctIndex: matchIndex,
                        explanation: question.explanation,
                        difficulty: question.difficulty,
                        subject: question.subject,
                        gradeLevel: question.gradeLevel
                    )
                }
            }
        }

        return question
    }

    /// Parse basic arithmetic: "What is 123 + 456?"
    private func tryBasicArithmetic(_ text: String) -> Double? {
        // Match patterns like:
        //   "what is 123 + 456"
        //   "123 + 456 ="
        //   "calculate 12 × 3"
        //   "what is 25 plus 17"
        //   "what is 100 minus 37"
        //   "what is 144 divided by 12"
        //   "what is 8 times 7"

        // First try symbolic operators: +, -, ×, ÷, *, /
        let symbolicPattern = #"(\d[\d,]*\.?\d*)\s*([+\-×÷\*\/])\s*(\d[\d,]*\.?\d*)"#
        if let match = text.range(of: symbolicPattern, options: .regularExpression) {
            let matchStr = String(text[match])
            return parseAndCompute(matchStr, symbolic: true)
        }

        // Word operators: "plus", "minus", "times", "divided by", "multiplied by"
        let wordPatterns: [(String, (Double, Double) -> Double)] = [
            (#"(\d[\d,]*\.?\d*)\s+plus\s+(\d[\d,]*\.?\d*)"#, { $0 + $1 }),
            (#"(\d[\d,]*\.?\d*)\s+minus\s+(\d[\d,]*\.?\d*)"#, { $0 - $1 }),
            (#"(\d[\d,]*\.?\d*)\s+times\s+(\d[\d,]*\.?\d*)"#, { $0 * $1 }),
            (#"(\d[\d,]*\.?\d*)\s+multiplied\s+by\s+(\d[\d,]*\.?\d*)"#, { $0 * $1 }),
            (#"(\d[\d,]*\.?\d*)\s+divided\s+by\s+(\d[\d,]*\.?\d*)"#, { $0 / $1 }),
        ]

        for (pattern, operation) in wordPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges >= 3 {
                let aStr = extractNumber(from: text, range: match.range(at: 1))
                let bStr = extractNumber(from: text, range: match.range(at: 2))
                if let a = parseNumber(aStr), let b = parseNumber(bStr) {
                    return operation(a, b)
                }
            }
        }

        return nil
    }

    /// Parse "A op B" with symbolic operators
    private func parseAndCompute(_ expr: String, symbolic: Bool) -> Double? {
        let operators: [(String, (Double, Double) -> Double)] = [
            ("+", { $0 + $1 }),
            ("-", { $0 - $1 }),
            ("×", { $0 * $1 }),
            ("*", { $0 * $1 }),
            ("÷", { $0 / $1 }),
            ("/", { $0 / $1 }),
        ]

        for (op, fn) in operators {
            let parts = expr.components(separatedBy: op)
            if parts.count == 2 {
                let aStr = parts[0].trimmingCharacters(in: .whitespaces)
                let bStr = parts[1].trimmingCharacters(in: .whitespaces)
                if let a = parseNumber(aStr), let b = parseNumber(bStr) {
                    if (op == "÷" || op == "/") && b == 0 { return nil }
                    return fn(a, b)
                }
            }
        }
        return nil
    }

    /// Parse "X% of Y"
    private func tryPercentOf(_ text: String) -> Double? {
        let pattern = #"(\d[\d,]*\.?\d*)\s*%\s*of\s+(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 3 {
            let pctStr = extractNumber(from: text, range: match.range(at: 1))
            let valStr = extractNumber(from: text, range: match.range(at: 2))
            if let pct = parseNumber(pctStr), let val = parseNumber(valStr) {
                return (pct / 100.0) * val
            }
        }
        return nil
    }

    /// Parse exponents: "2^5", "2⁵", "value of 2^5"
    private func tryExponent(_ text: String) -> Double? {
        // Match "X^N" or "X to the power of N"
        let caretPattern = #"(\d[\d,]*\.?\d*)\s*[\^]\s*(\d+)"#
        if let regex = try? NSRegularExpression(pattern: caretPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 3 {
            let baseStr = extractNumber(from: text, range: match.range(at: 1))
            let expStr = extractNumber(from: text, range: match.range(at: 2))
            if let base = parseNumber(baseStr), let exp = parseNumber(expStr) {
                return pow(base, exp)
            }
        }

        // Handle superscript digits: 2⁵ (Unicode superscript)
        let superscripts: [Character: Int] = [
            "⁰": 0, "¹": 1, "²": 2, "³": 3, "⁴": 4,
            "⁵": 5, "⁶": 6, "⁷": 7, "⁸": 8, "⁹": 9
        ]
        let superPattern = #"(\d+)([⁰¹²³⁴⁵⁶⁷⁸⁹]+)"#
        if let regex = try? NSRegularExpression(pattern: superPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 3 {
            let baseStr = extractNumber(from: text, range: match.range(at: 1))
            let superStr = extractString(from: text, range: match.range(at: 2))
            if let base = parseNumber(baseStr) {
                var expValue = 0
                for ch in superStr {
                    if let digit = superscripts[ch] {
                        expValue = expValue * 10 + digit
                    }
                }
                if expValue > 0 {
                    return pow(base, Double(expValue))
                }
            }
        }

        return nil
    }

    /// Parse simple algebra: "If x + 7 = 15, what is x?" → x = 8
    /// Handles: x + a = b, x - a = b, a + x = b, ax = b, x * a = b
    private func trySimpleAlgebra(_ text: String) -> Double? {
        // x + a = b
        let addPattern = #"[xX]\s*\+\s*(\d[\d,]*\.?\d*)\s*=\s*(\d[\d,]*\.?\d*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: addPattern) {
            return b - a
        }
        // a + x = b
        let addPattern2 = #"(\d[\d,]*\.?\d*)\s*\+\s*[xX]\s*=\s*(\d[\d,]*\.?\d*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: addPattern2) {
            return b - a
        }

        // x - a = b
        let subPattern = #"[xX]\s*-\s*(\d[\d,]*\.?\d*)\s*=\s*(\d[\d,]*\.?\d*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: subPattern) {
            return b + a
        }

        // ax = b (coefficient times x)
        let mulPattern = #"(\d[\d,]*\.?\d*)\s*[xX]\s*=\s*(\d[\d,]*\.?\d*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: mulPattern) {
            if a != 0 { return b / a }
        }

        // ax + c = b → x = (b - c) / a
        let linearPattern = #"(\d[\d,]*\.?\d*)\s*[xX]\s*\+\s*(\d[\d,]*\.?\d*)\s*=\s*(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: linearPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 4 {
            let aStr = extractNumber(from: text, range: match.range(at: 1))
            let cStr = extractNumber(from: text, range: match.range(at: 2))
            let bStr = extractNumber(from: text, range: match.range(at: 3))
            if let a = parseNumber(aStr), let c = parseNumber(cStr), let b = parseNumber(bStr), a != 0 {
                return (b - c) / a
            }
        }

        // ax - c = b → x = (b + c) / a
        let linearSubPattern = #"(\d[\d,]*\.?\d*)\s*[xX]\s*-\s*(\d[\d,]*\.?\d*)\s*=\s*(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: linearSubPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 4 {
            let aStr = extractNumber(from: text, range: match.range(at: 1))
            let cStr = extractNumber(from: text, range: match.range(at: 2))
            let bStr = extractNumber(from: text, range: match.range(at: 3))
            if let a = parseNumber(aStr), let c = parseNumber(cStr), let b = parseNumber(bStr), a != 0 {
                return (b + c) / a
            }
        }

        return nil
    }

    // MARK: - Geometry Formula Parsing

    /// Parse geometry questions: area, perimeter, volume of common shapes.
    /// Examples:
    ///   "What is the area of a rectangle with length 8 cm and width 5 cm?" → 8 * 5 = 40
    ///   "What is the perimeter of a rectangle with length 12 and width 7?" → 2*(12+7) = 38
    ///   "What is the area of a triangle with base 10 and height 6?" → 0.5*10*6 = 30
    ///   "What is the area of a square with side 9?" → 9*9 = 81
    private func tryGeometry(_ text: String) -> Double? {
        // Rectangle area: "area of a rectangle with length N and width M"
        // Also handles: "a rectangular garden is 10 meters long and 5 meters wide. What is the area?"
        let rectAreaPatterns = [
            #"area\s+of\s+(?:a\s+|the\s+)?rectangle\s+(?:with\s+)?length\s+(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:and\s+)?width\s+(\d[\d,]*\.?\d*)"#,
            #"area\s+of\s+(?:a\s+|the\s+)?rectangle\s+(?:with\s+)?(?:a\s+)?width\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:and\s+)?(?:a\s+)?length\s+(?:of\s+)?(\d[\d,]*\.?\d*)"#,
            #"area\s+of\s+(?:a\s+|the\s+)?rectangle\s+(?:that\s+)?(?:is\s+|measures?\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:by|x|×)\s*(\d[\d,]*\.?\d*)"#,
            #"rectangle\s+(?:with\s+)?(?:a\s+)?length\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:and\s+)?(?:a\s+)?width\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?.*?area"#,
            // "rectangular garden/room/field is 10 meters long and 5 meters wide" + area mentioned
            #"rectangular\s+\w+\s+(?:is\s+|that\s+is\s+|measuring\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*long\s+(?:and\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*wide"#,
            // "rectangular garden/room with length 10 and width 5"
            #"rectangular\s+\w+\s+(?:with\s+)?(?:a\s+)?length\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:and\s+)?(?:a\s+)?width\s+(?:of\s+)?(\d[\d,]*\.?\d*)"#,
        ]
        for pattern in rectAreaPatterns {
            if let (a, b) = extractTwoNumbers(text, pattern: pattern) {
                return a * b
            }
        }
        // Broad pattern: "N long and M wide" — only if the question mentions "area"
        if text.contains("area") {
            let longWidePattern = #"(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*long\s+(?:and\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*wide"#
            if let (a, b) = extractTwoNumbers(text, pattern: longWidePattern) {
                return a * b
            }
        }
        // Broad pattern: "N long and M wide" — if the question mentions "perimeter"
        if text.contains("perimeter") {
            let longWidePattern = #"(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*long\s+(?:and\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*wide"#
            if let (a, b) = extractTwoNumbers(text, pattern: longWidePattern) {
                return 2 * (a + b)
            }
        }

        // Rectangle perimeter: "perimeter of a rectangle with length N and width M"
        let rectPerimPatterns = [
            #"perimeter\s+of\s+(?:a\s+|the\s+)?rectangle\s+(?:with\s+)?length\s+(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:and\s+)?width\s+(\d[\d,]*\.?\d*)"#,
            #"perimeter\s+of\s+(?:a\s+|the\s+)?rectangle\s+(?:with\s+)?(?:a\s+)?width\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:and\s+)?(?:a\s+)?length\s+(?:of\s+)?(\d[\d,]*\.?\d*)"#,
            #"perimeter\s+of\s+(?:a\s+|the\s+)?rectangle\s+(?:that\s+)?(?:is\s+|measures?\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:by|x|×)\s*(\d[\d,]*\.?\d*)"#,
        ]
        for pattern in rectPerimPatterns {
            if let (a, b) = extractTwoNumbers(text, pattern: pattern) {
                return 2 * (a + b)
            }
        }

        // Square area: "area of a square with side N"
        let squareAreaPattern = #"area\s+of\s+(?:a\s+|the\s+)?square\s+(?:with\s+)?(?:a\s+)?side\s+(?:length\s+)?(?:of\s+)?(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: squareAreaPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2 {
            let sStr = extractNumber(from: text, range: match.range(at: 1))
            if let s = parseNumber(sStr) { return s * s }
        }

        // Square perimeter: "perimeter of a square with side N"
        let squarePerimPattern = #"perimeter\s+of\s+(?:a\s+|the\s+)?square\s+(?:with\s+)?(?:a\s+)?side\s+(?:length\s+)?(?:of\s+)?(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: squarePerimPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2 {
            let sStr = extractNumber(from: text, range: match.range(at: 1))
            if let s = parseNumber(sStr) { return 4 * s }
        }

        // Triangle area: "area of a triangle with base N and height M"
        let triAreaPattern = #"area\s+of\s+(?:a\s+|the\s+)?triangle\s+(?:with\s+)?(?:a\s+)?base\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft|inches|meters|units)?\s*(?:and\s+)?(?:a\s+)?height\s+(?:of\s+)?(\d[\d,]*\.?\d*)"#
        if let (base, height) = extractTwoNumbers(text, pattern: triAreaPattern) {
            return 0.5 * base * height
        }

        // Circle area: "area of a circle with radius N"
        let circleAreaPattern = #"area\s+of\s+(?:a\s+|the\s+)?circle\s+(?:with\s+)?(?:a\s+)?radius\s+(?:of\s+)?(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: circleAreaPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2 {
            let rStr = extractNumber(from: text, range: match.range(at: 1))
            if let r = parseNumber(rStr) { return Double.pi * r * r }
        }

        // Circle circumference: "circumference of a circle with radius N"
        let circleCircumPattern = #"circumference\s+of\s+(?:a\s+|the\s+)?circle\s+(?:with\s+)?(?:a\s+)?radius\s+(?:of\s+)?(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: circleCircumPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2 {
            let rStr = extractNumber(from: text, range: match.range(at: 1))
            if let r = parseNumber(rStr) { return 2 * Double.pi * r }
        }

        // Volume of rectangular prism: "volume ... length N width M height H"
        let volumePattern = #"volume\s+.*?length\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft)?\s*(?:,?\s*)?width\s+(?:of\s+)?(\d[\d,]*\.?\d*)\s*(?:cm|m|mm|in|ft)?\s*(?:,?\s*)?(?:and\s+)?height\s+(?:of\s+)?(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: volumePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 4 {
            let lStr = extractNumber(from: text, range: match.range(at: 1))
            let wStr = extractNumber(from: text, range: match.range(at: 2))
            let hStr = extractNumber(from: text, range: match.range(at: 3))
            if let l = parseNumber(lStr), let w = parseNumber(wStr), let h = parseNumber(hStr) {
                return l * w * h
            }
        }

        // Volume of cube: "volume of a cube with side N"
        let cubeVolumePattern = #"volume\s+of\s+(?:a\s+|the\s+)?cube\s+(?:with\s+)?(?:a\s+)?side\s+(?:length\s+)?(?:of\s+)?(\d[\d,]*\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: cubeVolumePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 2 {
            let sStr = extractNumber(from: text, range: match.range(at: 1))
            if let s = parseNumber(sStr) { return s * s * s }
        }

        return nil
    }

    // MARK: - Word Problem Parsing

    /// Try to parse common word problem patterns that boil down to simple arithmetic.
    /// Examples:
    ///   "A teacher has 24 students and wants to divide them into groups of 4"  → 24 / 4 = 6
    ///   "Each of 8 students gets 5 pencils. How many pencils in total?" → 8 * 5 = 40
    ///   "Sam has 15 apples and gives away 7" → 15 - 7 = 8
    private func tryWordProblem(_ text: String) -> Double? {
        // Pattern: "each of N ... M (items)" or "N (people) each get/gets/has M"
        // → multiplication: N * M
        let eachOfPattern = #"each\s+of\s+(?:his|her|their|the)?\s*(\d[\d,]*)\s+\w+\s+(?:a\s+)?(?:pack\s+of\s+|group\s+of\s+|set\s+of\s+|box\s+of\s+)?(\d[\d,]*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: eachOfPattern) {
            return a * b
        }

        // "N (things) each ... M" → N * M
        let nEachPattern = #"(\d[\d,]*)\s+\w+\s+each\s+(?:get|gets|has|have|receive|receives|need|needs|carry|carries|cost|costs)\s+(\d[\d,]*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: nEachPattern) {
            return a * b
        }

        // "divide/split N into groups of M" → N / M
        let divideIntoPattern = #"(?:divide|split|separate)\s+(?:\w+\s+)?(\d[\d,]*)\s+\w*\s*into\s+(?:groups?\s+of\s+|teams?\s+of\s+|sets?\s+of\s+)?(\d[\d,]*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: divideIntoPattern) {
            if b != 0 { return a / b }
        }

        // "N (items) shared/divided equally among M (people)" → N / M
        let sharedAmongPattern = #"(\d[\d,]*)\s+\w+\s+(?:shared|divided|distributed|split)\s+(?:equally\s+)?(?:among|between|into)\s+(\d[\d,]*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: sharedAmongPattern) {
            if b != 0 { return a / b }
        }

        // "has/have N ... buys/gets/receives M more" → N + M
        let getMorePattern = #"(?:has|have|had|starts?\s+with)\s+(\d[\d,]*)\s+\w+.*?(?:buys?|gets?|receives?|finds?|earns?|picks?\s+up|collects?)\s+(\d[\d,]*)\s+more"#
        if let (a, b) = extractTwoNumbers(text, pattern: getMorePattern) {
            return a + b
        }

        // "has/have N ... gives/loses/eats/spends M" → N - M
        let losesPattern = #"(?:has|have|had|starts?\s+with)\s+(\d[\d,]*)\s+\w+.*?(?:gives?\s+away|loses?|eats?|spends?|uses?|breaks?|drops?|sells?)\s+(\d[\d,]*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: losesPattern) {
            return a - b
        }

        // "N rows of M" or "M columns of N" → N * M
        let rowsOfPattern = #"(\d[\d,]*)\s+(?:rows?|columns?|lines?|shelves|boxes|bags|packs|groups|stacks|trays|plates|baskets|crates|bundles)\s+(?:of|with|containing)\s+(\d[\d,]*)"#
        if let (a, b) = extractTwoNumbers(text, pattern: rowsOfPattern) {
            return a * b
        }

        // "total/all ... N ... M" where it's asking "how many in total"
        // "If there are N classrooms with M students each" → N * M
        let nWithMEachPattern = #"(\d[\d,]*)\s+\w+\s+(?:with|containing|having)\s+(\d[\d,]*)\s+\w+\s+each"#
        if let (a, b) = extractTwoNumbers(text, pattern: nWithMEachPattern) {
            return a * b
        }

        return nil
    }

    // MARK: - Option Matching

    /// Find which option index matches the computed answer.
    /// Handles integers, decimals, formatted numbers, and common prefixes ($, etc.)
    private func findMatchingOption(answer: Double, options: [String]) -> Int? {
        for (index, option) in options.enumerated() {
            if optionMatchesAnswer(option: option, answer: answer) {
                return index
            }
        }
        return nil
    }

    /// Check if an option string represents the given answer value
    private func optionMatchesAnswer(option: String, answer: Double) -> Bool {
        // Strip common prefixes/suffixes: $, cm, cm², cm³, %, word-based units, etc.
        let cleaned = option
            .replacingOccurrences(of: "$", with: "")
            // Remove word-based area/volume/length units BEFORE removing spaces
            .replacingOccurrences(of: #"\s*(?:square\s+(?:meters|centimeters|inches|feet|kilometers|miles|yards|units|millimeters))"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*(?:cubic\s+(?:meters|centimeters|inches|feet|kilometers|units|millimeters))"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*(?:meters|centimeters|inches|feet|kilometers|miles|yards|millimeters|liters|gallons|ounces|pounds|grams|kilograms|seconds|minutes|hours|degrees|students|items|pieces|apples|books|pencils|people|groups|packs|boxes|sets|pairs|tickets|coins|marbles|candies|stickers|cookies|cupcakes|slices|pages)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "cm³", with: "")
            .replacingOccurrences(of: "cm²", with: "")
            .replacingOccurrences(of: "m²", with: "")
            .replacingOccurrences(of: "m³", with: "")
            .replacingOccurrences(of: "mm²", with: "")
            .replacingOccurrences(of: "mm", with: "")
            .replacingOccurrences(of: "km²", with: "")
            .replacingOccurrences(of: "km", with: "")
            .replacingOccurrences(of: "in²", with: "")
            .replacingOccurrences(of: "ft²", with: "")
            .replacingOccurrences(of: "cm", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Also try to extract just the number from text like "x = 7"
        let numberCandidates = [cleaned]
            + cleaned.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }

        for candidate in numberCandidates {
            if let optionValue = Double(candidate) {
                // Compare with tolerance for floating point
                if abs(optionValue - answer) < 0.001 {
                    return true
                }
            }
        }

        // Handle fractions in options like "2/3"
        let fractionParts = cleaned.components(separatedBy: "/")
        if fractionParts.count == 2,
           let num = Double(fractionParts[0]),
           let den = Double(fractionParts[1]),
           den != 0 {
            if abs(num / den - answer) < 0.001 {
                return true
            }
        }

        return false
    }

    // MARK: - Helpers

    private func parseNumber(_ str: String) -> Double? {
        let cleaned = str
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    private func extractNumber(from text: String, range: NSRange) -> String {
        guard let swiftRange = Range(range, in: text) else { return "" }
        return String(text[swiftRange])
    }

    private func extractString(from text: String, range: NSRange) -> String {
        guard let swiftRange = Range(range, in: text) else { return "" }
        return String(text[swiftRange])
    }

    private func extractTwoNumbers(_ text: String, pattern: String) -> (Double, Double)? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3 else { return nil }
        let aStr = extractNumber(from: text, range: match.range(at: 1))
        let bStr = extractNumber(from: text, range: match.range(at: 2))
        guard let a = parseNumber(aStr), let b = parseNumber(bStr) else { return nil }
        return (a, b)
    }
}
