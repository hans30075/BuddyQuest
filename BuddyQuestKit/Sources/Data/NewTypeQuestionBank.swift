import Foundation

// MARK: - New Type Question Bank

/// Static seed questions for the four new question types:
/// True/False, Fill-in-the-Blank, Ordering, and Matching.
/// Used by AdaptiveQuestionBankManager when seeding a new profile.
public enum NewTypeQuestionBank {

    // MARK: - Public API

    /// All new-type questions for a given subject.
    public static func questions(for subject: Subject) -> [Question] {
        switch subject {
        case .math:       return mathTrueFalse + mathOrdering + mathMatching
        case .languageArts: return elaTrueFalse + elaOrdering + elaMatching
        case .science:    return scienceTrueFalse + scienceOrdering + scienceMatching
        case .social:     return socialTrueFalse + socialOrdering + socialMatching
        }
    }

    /// All new-type questions across all subjects.
    public static var allQuestions: [Question] {
        Subject.allCases.flatMap { questions(for: $0) }
    }

    // =========================================================================
    // MARK: - MATH
    // =========================================================================

    // MARK: Math — True/False

    private static let mathTrueFalse: [Question] = [
        Question(
            questionText: "All squares are rectangles.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "A square has 4 right angles and opposite sides equal — it meets all rectangle requirements!",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "7 × 8 = 54",
            payload: .trueFalse(correctAnswer: false),
            explanation: "7 × 8 = 56, not 54.",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "An even number plus an even number is always even.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "Adding two even numbers always gives another even number!",
            subject: .math, difficulty: .medium, gradeLevel: .third
        ),
        Question(
            questionText: "1/2 is greater than 1/3.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "1/2 = 0.5 which is greater than 1/3 ≈ 0.33.",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "A triangle has 4 sides.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "A triangle has exactly 3 sides — that's why it's called a 'tri'-angle!",
            subject: .math, difficulty: .beginner, gradeLevel: .first
        ),
        Question(
            questionText: "100 centimeters equals 1 meter.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "'Centi' means one hundredth, so 100 centimeters = 1 meter.",
            subject: .math, difficulty: .easy, gradeLevel: .second
        ),
    ]

    // MARK: Math — Ordering

    private static let mathOrdering: [Question] = [
        Question(
            questionText: "Order these fractions from smallest to largest.",
            payload: .ordering(
                items: ["1/2", "1/4", "3/4", "1/8"],  // display order (shuffled)
                correctOrder: [3, 1, 0, 2]             // 1/8, 1/4, 1/2, 3/4
            ),
            explanation: "1/8 < 1/4 < 1/2 < 3/4.",
            subject: .math, difficulty: .medium, gradeLevel: .fourth
        ),
        Question(
            questionText: "Order these numbers from smallest to largest.",
            payload: .ordering(
                items: ["52", "25", "5", "205"],
                correctOrder: [2, 1, 0, 3]  // 5, 25, 52, 205
            ),
            explanation: "5 < 25 < 52 < 205.",
            subject: .math, difficulty: .beginner, gradeLevel: .second
        ),
        Question(
            questionText: "Order these units from smallest to largest.",
            payload: .ordering(
                items: ["meter", "centimeter", "kilometer", "millimeter"],
                correctOrder: [3, 1, 0, 2]  // mm, cm, m, km
            ),
            explanation: "millimeter < centimeter < meter < kilometer.",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
    ]

    // MARK: Math — Matching

    private static let mathMatching: [Question] = [
        Question(
            questionText: "Match each equation to its answer.",
            payload: .matching(
                leftItems: ["3 × 4", "7 + 8", "20 - 6", "9 × 3"],
                rightItems: ["27", "14", "15", "12"],  // shuffled
                correctMapping: [3, 2, 1, 0]           // 3×4→12(idx3), 7+8→15(idx2), 20-6→14(idx1), 9×3→27(idx0)
            ),
            explanation: "3×4=12, 7+8=15, 20-6=14, 9×3=27.",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "Match each shape to its number of sides.",
            payload: .matching(
                leftItems: ["Triangle", "Square", "Pentagon", "Hexagon"],
                rightItems: ["5", "6", "3", "4"],
                correctMapping: [2, 3, 0, 1]  // Triangle→3(idx2), Square→4(idx3), Pentagon→5(idx0), Hexagon→6(idx1)
            ),
            explanation: "Triangle=3, Square=4, Pentagon=5, Hexagon=6 sides.",
            subject: .math, difficulty: .easy, gradeLevel: .third
        ),
    ]

    // =========================================================================
    // MARK: - LANGUAGE ARTS
    // =========================================================================

    // MARK: ELA — True/False

    private static let elaTrueFalse: [Question] = [
        Question(
            questionText: "A noun is a word that describes an action.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "A noun names a person, place, or thing. A verb describes an action!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "Every sentence must end with a period.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "Sentences can also end with question marks (?) or exclamation points (!).",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "An adjective describes a noun.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "Adjectives like 'big', 'red', and 'happy' describe nouns!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "The word 'quickly' is an adverb.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "Adverbs describe how an action is done. 'Quickly' describes how something moves!",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),
        Question(
            questionText: "A synonym is a word that means the opposite.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "A synonym means the same or nearly the same. An antonym means the opposite!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .third
        ),
    ]

    // MARK: ELA — Ordering

    private static let elaOrdering: [Question] = [
        Question(
            questionText: "Put these words in alphabetical order.",
            payload: .ordering(
                items: ["cherry", "apple", "banana", "date"],
                correctOrder: [1, 2, 0, 3]  // apple, banana, cherry, date
            ),
            explanation: "Alphabetical order: apple, banana, cherry, date.",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "Put these story events in the correct order.",
            payload: .ordering(
                items: [
                    "The family arrived at the beach",
                    "They packed their bags",
                    "They swam in the ocean",
                    "They drove home at sunset"
                ],
                correctOrder: [1, 0, 2, 3]
            ),
            explanation: "First pack, then arrive, then swim, then drive home!",
            subject: .languageArts, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "Put these sentence parts in the correct order to make a sentence.",
            payload: .ordering(
                items: ["the red ball", "The dog", "in the park", "chased"],
                correctOrder: [1, 3, 0, 2]  // The dog chased the red ball in the park
            ),
            explanation: "\"The dog chased the red ball in the park.\"",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),
    ]

    // MARK: ELA — Matching

    private static let elaMatching: [Question] = [
        Question(
            questionText: "Match each word to its synonym.",
            payload: .matching(
                leftItems: ["happy", "big", "fast", "smart"],
                rightItems: ["intelligent", "large", "joyful", "quick"],
                correctMapping: [2, 1, 3, 0]  // happy→joyful(2), big→large(1), fast→quick(3), smart→intelligent(0)
            ),
            explanation: "Happy=joyful, big=large, fast=quick, smart=intelligent.",
            subject: .languageArts, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "Match each word to its part of speech.",
            payload: .matching(
                leftItems: ["run", "beautiful", "quickly", "cat"],
                rightItems: ["adjective", "noun", "verb", "adverb"],
                correctMapping: [2, 0, 3, 1]  // run→verb(2), beautiful→adjective(0), quickly→adverb(3), cat→noun(1)
            ),
            explanation: "Run=verb, beautiful=adjective, quickly=adverb, cat=noun.",
            subject: .languageArts, difficulty: .medium, gradeLevel: .third
        ),
    ]

    // =========================================================================
    // MARK: - SCIENCE
    // =========================================================================

    // MARK: Science — True/False

    private static let scienceTrueFalse: [Question] = [
        Question(
            questionText: "Plants need sunlight to make food.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "Plants use sunlight, water, and carbon dioxide for photosynthesis!",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "The sun revolves around the Earth.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "The Earth revolves around the Sun, not the other way around!",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "Spiders are insects.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "Spiders are arachnids, not insects. Insects have 6 legs; spiders have 8!",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "Water can exist as a solid, liquid, or gas.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "Ice (solid), water (liquid), and steam (gas) are the three states!",
            subject: .science, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "Sound travels faster than light.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "Light travels much faster than sound — that's why you see lightning before you hear thunder!",
            subject: .science, difficulty: .medium, gradeLevel: .fourth
        ),
    ]

    // MARK: Science — Ordering

    private static let scienceOrdering: [Question] = [
        Question(
            questionText: "Order the planets from closest to farthest from the Sun.",
            payload: .ordering(
                items: ["Earth", "Mars", "Mercury", "Venus"],
                correctOrder: [2, 3, 0, 1]  // Mercury, Venus, Earth, Mars
            ),
            explanation: "Mercury → Venus → Earth → Mars. My Very Excellent Mom...",
            subject: .science, difficulty: .medium, gradeLevel: .fourth
        ),
        Question(
            questionText: "Order these from smallest to largest.",
            payload: .ordering(
                items: ["cell", "organ", "organism", "tissue"],
                correctOrder: [0, 3, 1, 2]  // cell, tissue, organ, organism
            ),
            explanation: "Cells make tissues, tissues make organs, organs make organisms!",
            subject: .science, difficulty: .hard, gradeLevel: .fifth
        ),
        Question(
            questionText: "Order the water cycle steps.",
            payload: .ordering(
                items: ["Precipitation", "Evaporation", "Condensation", "Collection"],
                correctOrder: [1, 2, 0, 3]  // Evaporation, Condensation, Precipitation, Collection
            ),
            explanation: "Water evaporates, condenses into clouds, precipitates as rain, then collects!",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),
    ]

    // MARK: Science — Matching

    private static let scienceMatching: [Question] = [
        Question(
            questionText: "Match each animal to its habitat.",
            payload: .matching(
                leftItems: ["Polar bear", "Camel", "Monkey", "Dolphin"],
                rightItems: ["Ocean", "Rainforest", "Arctic", "Desert"],
                correctMapping: [2, 3, 1, 0]  // Polar bear→Arctic(2), Camel→Desert(3), Monkey→Rainforest(1), Dolphin→Ocean(0)
            ),
            explanation: "Polar bears live in the Arctic, camels in the desert, monkeys in rainforests, and dolphins in the ocean.",
            subject: .science, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "Match each organ to its function.",
            payload: .matching(
                leftItems: ["Heart", "Lungs", "Brain", "Stomach"],
                rightItems: ["Thinking", "Digesting food", "Pumping blood", "Breathing"],
                correctMapping: [2, 3, 0, 1]  // Heart→Pumping blood(2), Lungs→Breathing(3), Brain→Thinking(0), Stomach→Digesting(1)
            ),
            explanation: "Heart pumps blood, lungs help us breathe, the brain controls thinking, and the stomach digests food.",
            subject: .science, difficulty: .easy, gradeLevel: .third
        ),
    ]

    // =========================================================================
    // MARK: - SOCIAL SKILLS
    // =========================================================================

    // MARK: Social — True/False

    private static let socialTrueFalse: [Question] = [
        Question(
            questionText: "It's okay to feel angry sometimes.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "All feelings are valid! What matters is how we handle our anger.",
            subject: .social, difficulty: .beginner, gradeLevel: .first
        ),
        Question(
            questionText: "You should always agree with your friends to keep them happy.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "It's important to be honest and respectful. Good friends can disagree and still be friends!",
            subject: .social, difficulty: .easy, gradeLevel: .second
        ),
        Question(
            questionText: "Listening carefully to others shows respect.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "Active listening is one of the best ways to show respect and build trust!",
            subject: .social, difficulty: .beginner, gradeLevel: .first
        ),
        Question(
            questionText: "If someone is being bullied, it's best to just ignore it.",
            payload: .trueFalse(correctAnswer: false),
            explanation: "If you see bullying, tell a trusted adult. Everyone deserves to feel safe!",
            subject: .social, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "Taking turns is an important part of working in a team.",
            payload: .trueFalse(correctAnswer: true),
            explanation: "Taking turns makes sure everyone gets a chance to participate!",
            subject: .social, difficulty: .beginner, gradeLevel: .first
        ),
    ]

    // MARK: Social — Ordering

    private static let socialOrdering: [Question] = [
        Question(
            questionText: "Put these conflict resolution steps in order.",
            payload: .ordering(
                items: [
                    "Find a solution together",
                    "Stop and calm down",
                    "Talk about how you feel",
                    "Listen to the other person"
                ],
                correctOrder: [1, 2, 3, 0]  // Stop, Talk, Listen, Find solution
            ),
            explanation: "First calm down, then share feelings, listen, and work together on a solution!",
            subject: .social, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "Order these steps for making a new friend.",
            payload: .ordering(
                items: [
                    "Invite them to play",
                    "Introduce yourself",
                    "Ask about their interests",
                    "Say hello and smile"
                ],
                correctOrder: [3, 1, 2, 0]  // Say hello, introduce, ask interests, invite
            ),
            explanation: "Start with a smile, introduce yourself, learn about them, then invite them to play!",
            subject: .social, difficulty: .easy, gradeLevel: .second
        ),
    ]

    // MARK: Social — Matching

    private static let socialMatching: [Question] = [
        Question(
            questionText: "Match each feeling to the best coping strategy.",
            payload: .matching(
                leftItems: ["Angry", "Sad", "Nervous", "Frustrated"],
                rightItems: ["Practice first", "Count to 10", "Talk to a friend", "Take deep breaths"],
                correctMapping: [1, 2, 3, 0]  // Angry→Count to 10(1), Sad→Talk to friend(2), Nervous→Take breaths(3), Frustrated→Practice(0)
            ),
            explanation: "Different feelings need different strategies! Count when angry, talk when sad, breathe when nervous, and practice when frustrated.",
            subject: .social, difficulty: .easy, gradeLevel: .third
        ),
        Question(
            questionText: "Match each situation to the right response.",
            payload: .matching(
                leftItems: ["Someone shares a toy", "Someone falls down", "Someone feels left out", "Someone wins a game"],
                rightItems: ["Say congratulations", "Invite them to join", "Say thank you", "Ask if they're okay"],
                correctMapping: [2, 3, 1, 0]
            ),
            explanation: "Thank people who share, help those who fall, include those left out, and congratulate winners!",
            subject: .social, difficulty: .easy, gradeLevel: .second
        ),
    ]
}
